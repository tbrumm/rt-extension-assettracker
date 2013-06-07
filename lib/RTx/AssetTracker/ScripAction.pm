# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}

=head1 NAME

  RTx::AssetTracker::ScripAction - RT Action object

=head1 SYNOPSIS

  use RTx::AssetTracker::ScripAction;


=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in other modules.



=head1 METHODS

=cut

use strict;
use warnings;

package RTx::AssetTracker::ScripAction;
use base 'RTx::AssetTracker::Record';

sub Table {'AT_ScripActions'};

use RTx::AssetTracker::Template;

# {{{ sub _Accessible 
sub _Accessible  {
    my $self = shift;
    my %Cols = ( Name  => 'read',
		 Description => 'read',
		 ExecModule  => 'read',
		 Argument  => 'read',
		 Creator => 'read/auto',
		 Created => 'read/auto',
		 LastUpdatedBy => 'read/auto',
		 LastUpdated => 'read/auto'
       );
    return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub Create 

=head2 Create

Takes a hash. Creates a new Action entry.  should be better
documented.

=cut

sub Create  {
    my $self = shift;
    #TODO check these args and do smart things.
    return($self->SUPER::Create(@_));
}
# }}}

# {{{ sub Delete 
sub Delete  {
    my $self = shift;
    
    return (0, "ScripAction->Delete not implemented");
}
# }}}

# {{{ sub Load 

=head2 Load IDENTIFIER

Loads an action by its Name.

Returns: Id, Error Message

=cut

sub Load  {
    my $self = shift;
    my $identifier = shift;
    
    if (!$identifier) {
	return (0, $self->loc('Input error'));
    }	    
    
    if ($identifier !~ /\D/) {
	$self->SUPER::Load($identifier);
    }
    else {
	$self->LoadByCol('Name', $identifier);
	
    }

    if (@_) {
	# Set the template Id to the passed in template    
	my $template = shift;
	
	$self->{'Template'} = $template;
    }
    return ($self->Id, ($self->loc('[_1] ScripAction loaded', $self->Id)));
}
# }}}

# {{{ sub LoadAction 

=head2 LoadAction HASH

  Takes a hash consisting of AssetObj and TransactionObj.  Loads an RT::Action:: module.

=cut

sub LoadAction  {
    my $self = shift;
    my %args = ( TransactionObj => undef,
		 AssetObj => undef,
		 @_ );

    $self->{_AssetObj} = $args{AssetObj};
    
    #TODO: Put this in an eval  
    $self->ExecModule =~ /^(\w+)$/;
    my $module = $1;
    my $type = "RT::Action::". $module;
 
    eval "require $type" || die "Require of $type failed.\n$@\n";
    
    $self->{'Action'}  = $type->new ( Argument => $self->Argument,
                                      CurrentUser => $self->CurrentUser,
                                      ScripActionObj => $self, 
                                      ScripObj => $args{'ScripObj'},
                                      TemplateObj => $self->TemplateObj,
                                      TicketObj => $args{'AssetObj'},
                                      TransactionObj => $args{'TransactionObj'},
				    );
}
# }}}

# {{{ sub TemplateObj

=head2 TemplateObj

Return this action's template object

TODO: Why are we not using the Scrip's template object?


=cut

sub TemplateObj {
    my $self = shift;
    return undef unless $self->{Template};
    if ( !$self->{'TemplateObj'} ) {
        $self->{'TemplateObj'} = RTx::AssetTracker::Template->new( $self->CurrentUser );
        $self->{'TemplateObj'}->LoadById( $self->{'Template'} );

        if ( ( $self->{'TemplateObj'}->__Value('AssetType') == 0 )
            && $self->{'_AssetObj'} ) {
            my $tmptemplate = RTx::AssetTracker::Template->new( $self->CurrentUser );
            my ( $ok, $err ) = $tmptemplate->LoadAssetTypeTemplate(
                AssetType => $self->{'_AssetObj'}->AssetTypeObj->id,
                Name  => $self->{'TemplateObj'}->Name);

            if ( $tmptemplate->id ) {
                # found the queue-specific template with the same name
                $self->{'TemplateObj'} = $tmptemplate;
            }
        }

    }

    return ( $self->{'TemplateObj'} );
}
# }}}

# The following methods call the action object

# {{{ sub Prepare 

sub Prepare  {
    my $self = shift;
    $self->{_Message_ID} = 0;
    return ($self->Action->Prepare());
  
}
# }}}

# {{{ sub Commit 
sub Commit  {
    my $self = shift;
    return($self->Action->Commit());
    
    
}
# }}}

# {{{ sub Describe 
sub Describe  {
    my $self = shift;
    return ($self->Action->Describe());
    
}
# }}}

=head2 Action

Return the actual RT::Action object for this scrip.

=cut

sub Action {
    my $self = shift;
    return ($self->{'Action'});
}

# {{{ sub DESTROY
sub DESTROY {
    my $self=shift;
    $self->{'_AssetObj'} = undef;
    $self->{'Action'} = undef;
    $self->{'TemplateObj'} = undef;
}
# }}}

=head2 TODO

Between this, RTx::AssetTracker::Scrip and RT::Action::*, we need to be able to get rid of a 
class. This just reeks of too much complexity -- jesse

=cut

package RT::Action;

sub AssetObj { $_[0]->{TicketObj} }

package RTx::AssetTracker::ScripAction;


=head2 id

Returns the current value of id. 
(In the database, id is stored as int(11).)


=cut


=head2 Name

Returns the current value of Name. 
(In the database, Name is stored as varchar(200).)



=head2 SetName VALUE


Set Name to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(200).)


=cut


=head2 Description

Returns the current value of Description. 
(In the database, Description is stored as varchar(255).)



=head2 SetDescription VALUE


Set Description to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)


=cut


=head2 ExecModule

Returns the current value of ExecModule. 
(In the database, ExecModule is stored as varchar(60).)



=head2 SetExecModule VALUE


Set ExecModule to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ExecModule will be stored as a varchar(60).)


=cut


=head2 Argument

Returns the current value of Argument. 
(In the database, Argument is stored as varchar(255).)



=head2 SetArgument VALUE


Set Argument to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Argument will be stored as a varchar(255).)


=cut


=head2 Creator

Returns the current value of Creator. 
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created. 
(In the database, Created is stored as datetime.)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy. 
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated. 
(In the database, LastUpdated is stored as datetime.)


=cut



sub _CoreAccessible {
    {
     
        id =>
		{read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Name => 
		{read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        Description => 
		{read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        ExecModule => 
		{read => 1, write => 1, sql_type => 12, length => 60,  is_blob => 0,  is_numeric => 0,  type => 'varchar(60)', default => ''},
        Argument => 
		{read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        Creator => 
		{read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created => 
		{read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy => 
		{read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated => 
		{read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},

 }
};

RT::Base->_ImportOverlays();

1;
