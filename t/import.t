#!/usr/bin/perl

use strict;
use warnings;

use RTx::AssetTracker::Test tests => 57;

use RTx::AssetTracker;
use RTx::AssetTracker::Assets;
use RT::CurrentUser;
use YAML;
use Storable;

use constant RUNSCRIPS => 1;
use constant NOSCRIPS => 0;
use constant DETAILED => 1;
use constant NODETAIL => 0;

my ($cu, $asset1);

{
    diag "startup";
    my $user_obj = RT::User->new( $RT::SystemUser );
    $user_obj->LoadOrCreateByEmail( 'todd@chaka.net' );
    $user_obj->SetName( 'todd' );
    $user_obj->SetPrivileged( 1 );
    $user_obj->PrincipalObj->GrantRight( Right => 'SuperUser' );

    $cu = RT::CurrentUser->new();
    $cu->LoadByName('todd');

    my $group = RT::Group->new( $RT::SystemUser );
    $group->LoadUserDefinedGroup( 'group foo' );
    $group->Id || $group->CreateUserDefinedGroup( Name => 'group foo', Description => 'A test group' );

    my $type = RTx::AssetTracker::Type->new($cu);
    $type->Load("Servers");
    $type->Id || $type->Create(Name => "Servers");
    ok($type->Id, "Asset type 'Servers' exists");

    my $cf = RT::CustomField->new( $RT::SystemUser );
    $cf->LoadByName( Type => 0, Name => 'Foo' );
    $cf->Id || $cf->Create(
        Name => 'Foo',
        Type => 'FreeformSingle',
        LookupType => 'RTx::AssetTracker::Type-RTx::AssetTracker::Asset',
    );
    $cf->AddToObject( $type );

    my $cf2 = RT::CustomField->new( $RT::SystemUser );
    $cf2->LoadByName( Type => 0, Name => 'Bar' );
    $cf2->Id || $cf2->Create(
        Name => 'Bar',
        Type => 'FreeformMultiple',
        LookupType => 'RTx::AssetTracker::Type-RTx::AssetTracker::Asset',
    );
    $cf2->AddToObject( $type );

    $type = RTx::AssetTracker::Type->new($cu);
    $type->Load("Virtual");
    $type->Id || $type->Create(Name => "Virtual");
    ok($type->Id, "Asset type 'Virtual' exists");

    # an asset all tests can count on
    my $asset = { id => 'new', 
                     Name => "The one true asset $$",
                     Type => 'Servers',
                   Status => 'production', };

    my ($rv, $msgs) = Import(NOSCRIPS, NODETAIL, $asset);
    ok($rv, 'asset created');
    $asset1 = RTx::AssetTracker::Asset->new($cu);
    $asset1->Load($rv->[0]);

    #make sure CF exists

    #delete all IPs
    my $ips = RTx::AssetTracker::IPs->new($cu);
    $ips->UnLimit;
    while (my $ip = $ips->Next) {
        $ip->Delete;
    }
}

{
    diag "simple_import";
    my $before_count = asset_count();
    my $good_asset = { id => 'new', 
                     Name => "Simple Asset $$",
                     Type => 'Servers',
                   Status => 'production', };

    my ($rv, $msgs) = Import(NOSCRIPS, NODETAIL, $good_asset);
    ok($rv, 'simple asset create');
    is(asset_count(), $before_count+1);

}

{
    diag "simple_update";
    my $before_count = asset_count();
    my $good_asset = { id => 'new', 
                     Name => "Simple Asset for update $$",
              Description => "Simple Asset for update $$",
                     Type => 'Servers',
                   Status => 'production', };

    my ($rv, $msgs) = Import(NOSCRIPS, NODETAIL, $good_asset);
    ok($rv, 'simple asset create');
    is(asset_count(), $before_count+1);

    my $aid = $rv->[0];
    my $asset_update = { id => $aid,
                       Name => "Simple Asset updated $$",
                       Type => 'Virtual',
                     Status => 'test', };

    ($rv, $msgs) = Import(NOSCRIPS, NODETAIL, $asset_update);
    ok($rv, 'simple asset update');
    is(asset_count(), $before_count+1);

    is($rv->[0], $aid);
    my $asset = RTx::AssetTracker::Asset->new($cu);
    $asset->Load($aid);
    is($asset->Name, $asset_update->{Name});
    is($asset->TypeObj->Name, $asset_update->{Type});
    is($asset->Status, $asset_update->{Status});

}

{
    diag "import_new";
    my $before_count = asset_count();
    my $good_asset = { id => 'new', 
                     Name => "My Asset $$",
                     Type => 'Servers',
              Description => "new asset $$",
                   Status => 'dr', 
                    Owner => 'todd@chaka.net, root@localhost,@group foo',
                    Admin => 'todd@chaka.net',
                      Foo => 'foo value',
                 RefersTo => $asset1->URI,
           'IP Address' => 'eth0:127.0.0.1:ffffffffffff:22,80:22' };

    my ($rv, $msgs) = Import(NOSCRIPS, NODETAIL, $good_asset);
    ok($rv, 'asset created');
    is(asset_count(), $before_count+1);

    my $a = RTx::AssetTracker::Asset->new($cu);
    is(ref($rv), 'ARRAY', "list of asset IDs returned");
    $a->Load($rv->[0]);

    #basics
    is($a->Name, $good_asset->{Name});
    is($a->TypeObj->Name, $good_asset->{Type});
    is($a->Status, $good_asset->{Status});
    is($a->Description, $good_asset->{Description});

    #watchers
    ok($a->IsWatcher( Type => 'Owner', Email => 'todd@chaka.net' ), 'role watcher found');
    ok($a->IsWatcher( Type => 'Owner', Email => 'root@localhost' ), 'role watcher found');
    ok($a->IsWatcher( Type => 'Admin', Email => 'todd@chaka.net' ), 'role watcher found');
    my $g = RT::Group->new($cu);
    $g->LoadUserDefinedGroup("group foo");
    ok($a->IsWatcher( Type => 'Owner', PrincipalId => $g->PrincipalId ), 'group role watcher found');


    #custom fields
    is($a->FirstCustomFieldValue('Foo'), $good_asset->{Foo});

    #links
    my $refers = $a->RefersTo;
    is($refers->First->Target, $asset1->URI, 'link created');

    #ips
    my $ip = $a->IPs->First;
    is($ip->IP, '127.0.0.1', 'IP set');
    is($ip->Interface, 'eth0');
    is($ip->MAC, 'ffffffffffff');
}

{
    diag "update";
    my $good_asset = { id => 'new', 
                     Name => "My Asset to Update $$",
                     Type => 'Servers',
              Description => "new asset $$",
                   Status => 'dr', 
                    Owner => 'todd@chaka.net, root@localhost,@group foo',
                    Admin => 'todd@chaka.net',
                      Foo => 'foo value',
                 RefersTo => $asset1->URI,
           'IP Address' => 'eth0:127.0.0.3:ffffffffffff:22,80:22' };

    my ($rv, $msgs) = Import(NOSCRIPS, NODETAIL, $good_asset);
    ok($rv, 'asset created');

    my $updated_asset = Storable::dclone($good_asset);
    $updated_asset->{id} = $rv->[0];
    $updated_asset->{Foo} = 'bar value';
    $updated_asset->{Owner} = 'root@localhost,@group foo',
    $updated_asset->{'IP Address'} = 'eth0:127.0.0.4:ffffffffffff:22,80:22';
    $updated_asset->{RefersTo} = undef;
    $updated_asset->{DependsOn} = $asset1->URI;

    ($rv, $msgs) = Import(NOSCRIPS, NODETAIL, $updated_asset);
    ok($rv, 'asset updated');

    my $asset = RTx::AssetTracker::Asset->new($cu);
    $asset->Load($rv->[0]);
    is($asset->FirstCustomFieldValue('Foo'), $updated_asset->{Foo}, 'custom field updated');
    ok(!$asset->IsWatcher(Type => 'Owner', Email => 'todd@chaka.net'), 'watcher removed');
    ok( $asset->IsWatcher(Type => 'Owner', Email => 'root@localhost'), 'watcher still there');

    is($asset->RefersTo->Count, 0, 'link removed');
    is($asset->DependsOn->Count, 1, 'link created');

    my @ips = $asset->IPsAsList;
    is(@ips, 1);
    is($ips[0], '127.0.0.4', 'found updated IP');
}

{
    diag "bad_import";
    my $before_count = asset_count();
    my $good_asset = { id => 'new', 
                     Name => "My Asset $$",
                     Type => 'Servers',
              Description => "new asset $$",
                   Status => 'dr', 
                    Owner => 'todd@chaka.net, root@localhost',
                    Admin => 'todd@chaka.net',
                      Foo => 'foo value', };

    my $bad_asset = Storable::dclone($good_asset);
    $bad_asset->{id} = 'bad'; #asset id must be an integer or new
    my ($rv, $msgs) = Import(NOSCRIPS, NODETAIL, $good_asset, $bad_asset);
    is($rv, 0, "not imported");
    is($before_count, asset_count());
}

{
    diag "test_update_transactions";
    my $good_asset = { id => 'new', 
                     Name => "Simple Asset transactions $$",
                     Type => 'Servers',
                   Status => 'production', };

    my ($rv, $msgs) = Import(NOSCRIPS, DETAILED, $good_asset);
    ok($rv, 'simple asset create');
    my $aid = $rv->[0];

    my $asset = RTx::AssetTracker::Asset->new($cu);
    $asset->Load($aid);
    is($asset->Transactions->Count, 1, 'create transaction');

    my $asset_update = { id => $aid,
                       Name => "Simple Asset transactions $$",
                       Type => 'Virtual',
                     Status => 'test', };

    ($rv, $msgs) = Import(NOSCRIPS, DETAILED, $asset_update);
    ok($rv, 'simple asset update');

    $asset = RTx::AssetTracker::Asset->new($cu);
    $asset->Load($aid);
    is($asset->Transactions->Count, 4, 'update, type, and status transactions');

    $asset_update = { id => $aid,
                       Name => "Simple Asset transactions $$",
                       Type => 'Servers',
                      Admin => 'todd@chaka.net',
                     Status => 'test', };

    ($rv, $msgs) = Import(NOSCRIPS, DETAILED, $asset_update);
    ok($rv, 'simple asset update');

    $asset = RTx::AssetTracker::Asset->new($cu);
    $asset->Load($aid);
    is($asset->Transactions->Count, 7, 'watcher, update and type transactions');

}


{
    diag "test_multicf_import";
    my $before_count = asset_count();
    my @vals = ( 'one', 'two', 'three' );

    my $good_asset = { id => 'new', 
                     Name => "MultiCF Asset $$",
                     Type => 'Servers',
                   Status => 'production',
                      Bar => join( "\n", @vals ) };

    my ($rv, $msgs) = Import(NOSCRIPS, NODETAIL, $good_asset);
    ok($rv, 'multi-value cf import');
    is(asset_count(), $before_count+1);

    my $a = RTx::AssetTracker::Asset->new($cu);
    is(ref($rv), 'ARRAY', "list of asset IDs returned");
    $a->Load($rv->[0]);

    my @new_vals = map { $_->Content } @{ $a->CustomFieldValues('Bar')->ItemsArrayRef };

    is_deeply(
        \@vals,
        \@new_vals,
        join(' ', @vals)
        );

    push @vals, 'four';

    $good_asset = { id => $a->Id,
                     Name => "MultiCF Asset $$",
                     Type => 'Servers',
                   Status => 'production',
                      Bar => join( "\n", @vals ) };

    ($rv, $msgs) = Import(NOSCRIPS, NODETAIL, $good_asset);
    ok($rv, 'add cf value');

    @new_vals = map { $_->Content } @{ $a->CustomFieldValues('Bar')->ItemsArrayRef };

    is_deeply(
        \@vals,
        \@new_vals,
        join(' ', @vals)
        );

    pop @vals;
    shift @vals;

    $good_asset = { id => $a->Id,
                     Name => "MultiCF Asset $$",
                     Type => 'Servers',
                   Status => 'production',
                      Bar => join( "\n", @vals ) };

    ($rv, $msgs) = Import(NOSCRIPS, NODETAIL, $good_asset);
    ok($rv, 'delete cf values');

    @new_vals = map { $_->Content } @{ $a->CustomFieldValues('Bar')->ItemsArrayRef };

    is_deeply(
        \@vals,
        \@new_vals,
        join(' ', @vals)
        );
}


sub asset_count {
    my $assets = RTx::AssetTracker::Assets->new($cu);
    $assets->UnLimit;
    return $assets->Count;
}

sub asset2headers {
    my ($asset) = @_;
    my $headers = [ 'id', grep { $_ ne 'id' } keys %$asset ]; #id always has to be the first column
    return $headers;
}

sub asset2row {
    my ($headers, $asset) = @_;

    my $row = [ map { $asset->{$_} } @$headers ];
    return $row;
}

sub asset_name {
}

sub Import {
    my ($runscrips, $detailed, @assets) = @_;

    my $headers = asset2headers($assets[0]);
    my @rows;
    for (@assets) {
        push @rows, asset2row($headers, $_);
    }

    my $assets = RTx::AssetTracker::Assets->new($cu);
    return $assets->Import($headers, \@rows, $runscrips, $detailed);
}
