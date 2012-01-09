# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2013 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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

  RTx::AssetTracker::Scrip - an RT Scrip object

=head1 SYNOPSIS

  use RTx::AssetTracker::Scrip;

=head1 DESCRIPTION


=head1 METHODS


=cut

use strict;
use warnings;

package RTx::AssetTracker::Scrip;
use base 'RTx::AssetTracker::Record';

sub Table {'AT_Scrips'};

use RTx::AssetTracker::Type;
use RTx::AssetTracker::Template;
use RTx::AssetTracker::ScripCondition;
use RTx::AssetTracker::ScripAction;
use RTx::AssetTracker::Scrips;
use RTx::AssetTracker::ObjectScrip;


# {{{ sub Create

=head2 Create

Creates a new entry in the Scrips table. Takes a paramhash with:

        AssetType              => 0,
        Description            => undef,
        Template               => undef,
        ScripAction            => undef,
        ScripCondition         => undef,
        CustomPrepareCode      => undef,
        CustomCommitCode       => undef,
        CustomIsApplicableCode => undef,




Returns (retval, msg);
retval is 0 for failure or scrip id.  msg is a textual description of what happened.

=cut

sub Create {
    my $self = shift;
    my %args = (
        AssetType              => 0,
        Template               => 0,                     # name or id
        ScripAction            => 0,                     # name or id
        ScripCondition         => 0,                     # name or id
        Stage                  => 'TransactionCreate',
        Description            => undef,
        CustomPrepareCode      => undef,
        CustomCommitCode       => undef,
        CustomIsApplicableCode => undef,
        @_
    );

    if ($args{CustomPrepareCode} || $args{CustomCommitCode} || $args{CustomIsApplicableCode}) {
        unless ( $self->CurrentUser->HasRight( Object => $RT::System,
                                               Right  => 'ExecuteCode' ) )
        {
            return ( 0, $self->loc('Permission Denied') );
        }
    }

    unless ( $args{'AssetType'} ) {
        unless ( $self->CurrentUser->HasRight( Object => $RT::System,
                                               Right  => 'ModifyScrips' ) )
        {
            return ( 0, $self->loc('Permission Denied') );
        }
        $args{'AssetType'} = 0;    # avoid undef sneaking in
    }
    else {
        my $AssetTypeObj = RTx::AssetTracker::Type->new( $self->CurrentUser );
        $AssetTypeObj->Load( $args{'AssetType'} );
        unless ( $AssetTypeObj->id ) {
            return ( 0, $self->loc('Invalid asset type') );
        }
        unless ( $AssetTypeObj->CurrentUserHasRight('ModifyScrips') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
        $args{'AssetType'} = $AssetTypeObj->id;
    }

    #TODO +++ validate input

    require RTx::AssetTracker::ScripAction;
    return ( 0, $self->loc("Action is mandatory argument") )
        unless $args{'ScripAction'};
    my $action = RTx::AssetTracker::ScripAction->new( $self->CurrentUser );
    $action->Load( $args{'ScripAction'} );
    return ( 0, $self->loc( "Action '[_1]' not found", $args{'ScripAction'} ) ) 
        unless $action->Id;

    require RTx::AssetTracker::Template;
    return ( 0, $self->loc("Template is mandatory argument") )
        unless $args{'Template'};
    my $template = RTx::AssetTracker::Template->new( $self->CurrentUser );
    $template->Load( $args{'Template'} );
    return ( 0, $self->loc( "Template '[_1]' not found", $args{'Template'} ) )
        unless $template->Id;

    require RTx::AssetTracker::ScripCondition;
    return ( 0, $self->loc("Condition is mandatory argument") )
        unless $args{'ScripCondition'};
    my $condition = RTx::AssetTracker::ScripCondition->new( $self->CurrentUser );
    $condition->Load( $args{'ScripCondition'} );
    return ( 0, $self->loc( "Condition '[_1]' not found", $args{'ScripCondition'} ) )
        unless $condition->Id;

    if ( $args{'Stage'} eq 'Disabled' ) {
        $RT::Logger->warning("Disabled Stage is deprecated");
        $args{'Stage'} = 'TransactionCreate';
        $args{'Disabled'} = 1;
    }
    $args{'Disabled'} ||= 0;

    my ( $id, $msg ) = $self->SUPER::Create(
        Template               => $template->Id,
        ScripCondition         => $condition->id,
        ScripAction            => $action->Id,
        Disabled               => $args{'Disabled'},
        Description            => $args{'Description'},
        CustomPrepareCode      => $args{'CustomPrepareCode'},
        CustomCommitCode       => $args{'CustomCommitCode'},
        CustomIsApplicableCode => $args{'CustomIsApplicableCode'},
    );
    return ( $id, $msg ) unless $id;

    (my $status, $msg) = RTx::AssetTracker::ObjectScrip->new( $self->CurrentUser )->Add(
        Scrip    => $self,
        Stage    => $args{'Stage'},
        ObjectId => $args{'AssetType'},
    );
    $RT::Logger->error( "Couldn't add scrip: $msg" ) unless $status;

    return ( $id, $self->loc('Scrip Created') );
}



=head2 Delete

Delete this object

=cut

sub Delete {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ModifyScrips') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    RTx::AssetTracker::ObjectScrip->new( $self->CurrentUser )->DeleteAll( Scrip => $self );

    return ( $self->SUPER::Delete(@_) );
}

sub IsAdded {
    my $self = shift;
    my $record = RTx::AssetTracker::ObjectScrip->new( $self->CurrentUser );
    $record->LoadByCols( Scrip => $self->id, ObjectId => shift || 0 );
    return undef unless $record->id;
    return $record;
}

sub AddedTo {
    my $self = shift;
    return RTx::AssetTracker::ObjectScrip->new( $self->CurrentUser )
        ->AddedTo( Scrip => $self );
}

sub NotAddedTo {
    my $self = shift;
    return RTx::AssetTracker::ObjectScrip->new( $self->CurrentUser )
        ->NotAddedTo( Scrip => $self );
}

sub AddToObject {
    my $self = shift;
    my %args = @_%2? (ObjectId => @_) : (@_);

    my $assettype;
    if ( $args{'ObjectId'} ) {

        $args{'ObjectId'} = $assettype->id;
    }
    return ( 0, $self->loc('Permission Denied') )
        unless $self->CurrentUser->PrincipalObj->HasRight(
            Object => $assettype || $RT::System, Right => 'ModifyScrips',
        )
    ;

    my $tname = $self->TemplateObj->Name;
    my $template = RT::Template->new( $self->CurrentUser );
    $template->LoadAssetTypeTemplate( Assettype => $assettype? $assettype->id : 0, Name => $tname );
    $template->LoadGlobalTemplate( $tname ) if $assettype && !$template->id;
    unless ( $template->id ) {
        if ( $assettype ) {
            return (0, $self->loc('No template [_1] in the asset type', $tname));
        } else {
            return (0, $self->loc('No global template [_1]', $tname));
        }
    }

    my $rec = RTx::AssetTracker::ObjectScrip->new( $self->CurrentUser );
    return $rec->Add( %args, Scrip => $self );
}

sub RemoveFromObject {
    my $self = shift;
    my %args = @_%2? (ObjectId => @_) : (@_);

    my $assettype;
    if ( $args{'ObjectId'} ) {
        $assettype = RTx::AssetTracker::Type->new( $self->CurrentUser );
        $assettype->Load( $args{'ObjectId'} );
        return (0, $self->loc('Invalid asset type id'))
            unless $assettype->id;
    }
    return ( 0, $self->loc('Permission Denied') )
        unless $self->CurrentUser->PrincipalObj->HasRight(
            Object => $assettype || $RT::System, Right => 'ModifyScrips',
        )
    ;

    my $rec = RTx::AssetTracker::ObjectScrip->new( $self->CurrentUser );
    $rec->LoadByCols( Scrip => $self->id, ObjectId => $args{'ObjectId'} );
    return (0, $self->loc('Scrip is not added') ) unless $rec->id;
    return $rec->Delete;
}

=head2 ActionObj

Retuns an RT::Action object with this Scrip's Action

=cut

sub ActionObj {
    my $self = shift;

    unless ( defined $self->{'ScripActionObj'} ) {
        require RTx::AssetTracker::ScripAction;

        $self->{'ScripActionObj'} = RTx::AssetTracker::ScripAction->new( $self->CurrentUser );

        #TODO: why are we loading Actions with templates like this.
        # two separate methods might make more sense
        $self->{'ScripActionObj'}->Load( $self->ScripAction, $self->Template );
    }
    return ( $self->{'ScripActionObj'} );
}



=head2 ConditionObj

Retuns an L<RTx::AssetTracker::ScripCondition> object with this Scrip's IsApplicable

=cut

sub ConditionObj {
    my $self = shift;

    my $res = RTx::AssetTracker::ScripCondition->new( $self->CurrentUser );
    $res->Load( $self->ScripCondition );
    return $res;
}


=head2 LoadModules

Loads scrip's condition and action modules.

=cut

sub LoadModules {
    my $self = shift;

    $self->ConditionObj->LoadCondition;
    $self->ActionObj->LoadAction;
}


=head2 TemplateObj

Retuns an RTx::AssetTracker::Template object with this Scrip's Template

=cut

sub TemplateObj {
    my $self = shift;

    unless ( defined $self->{'TemplateObj'} ) {
        require RTx::AssetTracker::Template;
        $self->{'TemplateObj'} = RTx::AssetTracker::Template->new( $self->CurrentUser );
        $self->{'TemplateObj'}->Load( $self->Template );
    }
    return ( $self->{'TemplateObj'} );
}

=head2 Stage

Takes AssetObj named argument and returns scrip's stage when
added to asset's type.

=cut

sub Stage {
    my $self = shift;
    my %args = ( AssetObj => undef, @_ );

    my $assettype = $args{'AssetObj'}->AssetType;
    my $rec = RTx::AssetTracker::ObjectScrip->new( $self->CurrentUser );
    $rec->LoadByCols( Scrip => $self->id, ObjectId => $assettype );
    return $rec->Stage if $rec->id;

    $rec->LoadByCols( Scrip => $self->id, ObjectId => 0 );
    return $rec->Stage if $rec->id;

    return undef;
}


=head2 Apply { AssetObj => undef, TransactionObj => undef}

This method instantiates the ScripCondition and ScripAction objects for a
single execution of this scrip. it then calls the IsApplicable method of the 
ScripCondition.
If that succeeds, it calls the Prepare method of the
ScripAction. If that succeeds, it calls the Commit method of the ScripAction.

Usually, the asset and transaction objects passed to this method
should be loaded by the SuperUser role

=cut


# XXX TODO : This code appears to be obsoleted in favor of similar code in Scrips->Apply.
# Why is this here? Is it still called?

sub Apply {
    my $self = shift;
    my %args = ( AssetObj       => undef,
                 TransactionObj => undef,
                 @_ );

    $RT::Logger->debug("Now applying scrip ".$self->Id . " for transaction ".$args{'TransactionObj'}->id);

    my $ApplicableTransactionObj = $self->IsApplicable( AssetObj       => $args{'AssetObj'},
                                                        TransactionObj => $args{'TransactionObj'} );
    unless ( $ApplicableTransactionObj ) {
        return undef;
    }

    if ( $ApplicableTransactionObj->id != $args{'TransactionObj'}->id ) {
        $RT::Logger->debug("Found an applicable transaction ".$ApplicableTransactionObj->Id . " in the same batch with transaction ".$args{'TransactionObj'}->id);
    }

    #If it's applicable, prepare and commit it
    $RT::Logger->debug("Now preparing scrip ".$self->Id . " for transaction ".$ApplicableTransactionObj->id);
    unless ( $self->Prepare( AssetObj       => $args{'AssetObj'},
                             TransactionObj => $ApplicableTransactionObj )
      ) {
        return undef;
    }

    $RT::Logger->debug("Now commiting scrip ".$self->Id . " for transaction ".$ApplicableTransactionObj->id);
    unless ( $self->Commit( AssetObj => $args{'AssetObj'},
                            TransactionObj => $ApplicableTransactionObj)
      ) {
        return undef;
    }

    $RT::Logger->debug("We actually finished scrip ".$self->Id . " for transaction ".$ApplicableTransactionObj->id);
    return (1);

}



=head2 IsApplicable

Calls the  Condition object's IsApplicable method

Upon success, returns the applicable Transaction object.
Otherwise, undef is returned.

If the Scrip is in the TransactionCreate Stage (the usual case), only test
the associated Transaction object to see if it is applicable.

For Scrips in the TransactionBatch Stage, test all Transaction objects
created during the Asset object's lifetime, and returns the first one
that is applicable.

=cut

sub IsApplicable {
    my $self = shift;
    my %args = ( AssetObj       => undef,
                 TransactionObj => undef,
                 @_ );

    my $return;
    eval {

	my @Transactions;

        my $stage = $self->Stage( AssetObj => $args{'AssetObj'} );
        unless ( $stage ) {
	    $RT::Logger->error(
                "Scrip #". $self->id ." is not applied to"
                ." asset type #". $args{'AssetObj'}->Type
            );
	    return (undef);
        }
        elsif ( $stage eq 'TransactionCreate') {
	    # Only look at our current Transaction
	    @Transactions = ( $args{'TransactionObj'} );
        }
        elsif ( $stage eq 'TransactionBatch') {
	    # Look at all Transactions in this Batch
            @Transactions = @{ $args{'AssetObj'}->TransactionBatch || [] };
        }
	else {
	    $RT::Logger->error( "Unknown Scrip stage: '$stage'" );
	    return (undef);
	}
	my $ConditionObj = $self->ConditionObj;
	foreach my $TransactionObj ( @Transactions ) {
	    # in TxnBatch stage we can select scrips that are not applicable to all txns
	    my $txn_type = $TransactionObj->Type;
	    next unless( $ConditionObj->ApplicableTransTypes =~ /(?:^|,)(?:Any|\Q$txn_type\E)(?:,|$)/i );
	    # Load the scrip's Condition object
	    $ConditionObj->LoadCondition(
		ScripObj       => $self,
		AssetObj       => $args{'AssetObj'},
		TransactionObj => $TransactionObj,
	    );

            if ( $ConditionObj->IsApplicable() ) {
	        # We found an application Transaction -- return it
                $return = $TransactionObj;
                last;
            }
	}
    };

    if ($@) {
        $RT::Logger->error( "Scrip IsApplicable " . $self->Id . " died. - " . $@ );
        return (undef);
    }

            return ($return);

}



=head2 Prepare

Calls the action object's prepare method

=cut

sub Prepare {
    my $self = shift;
    my %args = ( AssetObj       => undef,
                 TransactionObj => undef,
                 @_ );

    my $return;
    eval {
        $self->ActionObj->LoadAction( ScripObj       => $self,
                                      AssetObj       => $args{'AssetObj'},
                                      TransactionObj => $args{'TransactionObj'},
        );

        $return = $self->ActionObj->Prepare();
    };
    if ($@) {
        $RT::Logger->error( "Scrip Prepare " . $self->Id . " died. - " . $@ );
        return (undef);
    }
        unless ($return) {
        }
        return ($return);
}



=head2 Commit

Calls the action object's commit method

=cut

sub Commit {
    my $self = shift;
    my %args = ( AssetObj       => undef,
                 TransactionObj => undef,
                 @_ );

    my $return;
    eval {
        $return = $self->ActionObj->Commit();
    };

#Searchbuilder caching isn't perfectly coherent. got to reload the asset object, since it
# may have changed
    $args{'AssetObj'}->Load( $args{'AssetObj'}->Id );

    if ($@) {
        $RT::Logger->error( "Scrip Commit " . $self->Id . " died. - " . $@ );
        return (undef);
    }

    # Not destroying or weakening hte Action and Condition here could cause a
    # leak

    return ($return);
}





# does an acl check and then passes off the call
sub _Set {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
        @_,
    );

    unless ( $self->CurrentUserHasRight('ModifyScrips') ) {
        $RT::Logger->debug( "CurrentUser can't modify Scrips" );
        return ( 0, $self->loc('Permission Denied') );
    }


    if (exists $args{Value}) {
        if ($args{Field} eq 'CustomIsApplicableCode' || $args{Field} eq 'CustomPrepareCode' || $args{Field} eq 'CustomCommitCode') {
            unless ( $self->CurrentUser->HasRight( Object => $RT::System,
                                                   Right  => 'ExecuteCode' ) ) {
                return ( 0, $self->loc('Permission Denied') );
            }
        }
        elsif ($args{Field} eq 'AssetType') {
            if ($args{Value}) {
                # moving to another asset type
                my $assettype = RTx::AssetTracker::Type->new( $self->CurrentUser );
                $assettype->Load($args{Value});
                unless ($assettype->Id and $assettype->CurrentUserHasRight('ModifyScrips')) {
                    return ( 0, $self->loc('Permission Denied') );
                }
            } else {
                # moving to global
                unless ($self->CurrentUser->HasRight( Object => RT->System, Right => 'ModifyScrips' )) {
                    return ( 0, $self->loc('Permission Denied') );
                }
            }
        }
        elsif ($args{Field} eq 'Template') {
            my $template = RT::Template->new( $self->CurrentUser );
            $template->Load($args{Value});
            unless ($template->Id and $template->CurrentUserCanRead) {
                return ( 0, $self->loc('Permission Denied') );
            }
        }
    }

    return $self->SUPER::_Set(@_);
}


# does an acl check and then passes off the call
sub _Value {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ShowScrips') ) {
        $RT::Logger->debug( "CurrentUser can't see scrip #". $self->__Value('id') );
        return (undef);
    }

    return $self->__Value(@_);
}



=head2 CurrentUserHasRight

Helper menthod for HasRight. Presets Principal to CurrentUser then 
calls HasRight.

=cut

sub CurrentUserHasRight {
    my $self  = shift;
    my $right = shift;
    return ( $self->HasRight( Principal => $self->CurrentUser->UserObj,
                              Right     => $right ) );

}



=head2 HasRight

Takes a param-hash consisting of "Right" and "Principal"  Principal is 
an RT::User object or an RT::CurrentUser object. "Right" is a textual
Right string that applies to Scrips.

=cut

sub HasRight {
    my $self = shift;
    my %args = ( Right     => undef,
                 Principal => undef,
                 @_ );

    my $assettypes = $self->AddedTo;
    my $found = 0;
    while ( my $assettype = $assettypes->Next ) {
        return 1 if $args{'Principal'}->HasRight(
            Right  => $args{'Right'},
            Object => $assettype,
        );
        $found = 1;
    }
    return $args{'Principal'}->HasRight(
        Object => $RT::System,
        Right  => $args{'Right'},
    ) unless $found;
    return 0;
}



=head2 CompileCheck

This routine compile-checks the custom prepare, commit, and is-applicable code
to see if they are syntactically valid Perl. We eval them in a codeblock to
avoid actually executing the code.

If one of the fields has a compile error, only the first is reported.

Returns an (ok, message) pair.

=cut

sub CompileCheck {
    my $self = shift;

    for my $method (qw/CustomPrepareCode CustomCommitCode CustomIsApplicableCode/) {
        my $code = $self->$method;
        next if !defined($code);

        do {
            no strict 'vars';
            eval "sub { $code \n }";
        };
        next if !$@;

        my $error = $@;
        return (0, $self->loc("Couldn't compile [_1] codeblock '[_2]': [_3]", $method, $code, $error));
    }
}


=head2 SetScripAction

=cut

sub SetScripAction {
    my $self  = shift;
    my $value = shift;

    return ( 0, $self->loc("Action is mandatory argument") ) unless $value;

    require RTx::AssetTracker::ScripAction;
    my $action = RTx::AssetTracker::ScripAction->new( $self->CurrentUser );
    $action->Load($value);
    return ( 0, $self->loc( "Action '[_1]' not found", $value ) )
      unless $action->Id;

    return $self->_Set( Field => 'ScripAction', Value => $action->Id );
}

=head2 SetScripCondition

=cut

sub SetScripCondition {
    my $self  = shift;
    my $value = shift;

    return ( 0, $self->loc("Condition is mandatory argument") )
      unless $value;

    require RTx::AssetTracker::ScripCondition;
    my $condition = RTx::AssetTracker::ScripCondition->new( $self->CurrentUser );
    $condition->Load($value);

    return ( 0, $self->loc( "Condition '[_1]' not found", $value ) )
      unless $condition->Id;

    return $self->_Set( Field => 'ScripCondition', Value => $condition->Id );
}

=head2 SetTemplate

=cut

sub SetTemplate {
    my $self  = shift;
    my $value = shift;

    return ( 0, $self->loc("Template is mandatory argument") ) unless $value;

    require RTx::AssetTracker::Template;
    my $template = RTx::AssetTracker::Template->new( $self->CurrentUser );
    $template->Load($value);
    return ( 0, $self->loc( "Template '[_1]' not found", $value ) )
      unless $template->Id;

    return $self->_Set( Field => 'Template', Value => $template->Id );
}


=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 Description

Returns the current value of Description.
(In the database, Description is stored as varchar(255).)



=head2 SetDescription VALUE


Set Description to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)


=cut


=head2 ScripCondition

Returns the current value of ScripCondition.
(In the database, ScripCondition is stored as int(11).)



=head2 SetScripCondition VALUE


Set ScripCondition to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ScripCondition will be stored as a int(11).)


=cut


=head2 ScripConditionObj

Returns the ScripCondition Object which has the id returned by ScripCondition


=cut

sub ScripConditionObj {
	my $self = shift;
	my $ScripCondition =  RTx::AssetTracker::ScripCondition->new($self->CurrentUser);
	$ScripCondition->Load($self->__Value('ScripCondition'));
	return($ScripCondition);
}

=head2 ScripAction

Returns the current value of ScripAction.
(In the database, ScripAction is stored as int(11).)



=head2 SetScripAction VALUE


Set ScripAction to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ScripAction will be stored as a int(11).)


=cut


=head2 ScripActionObj

Returns the ScripAction Object which has the id returned by ScripAction


=cut

sub ScripActionObj {
	my $self = shift;
	my $ScripAction =  RTx::AssetTracker::ScripAction->new($self->CurrentUser);
	$ScripAction->Load($self->__Value('ScripAction'));
	return($ScripAction);
}

=head2 ConditionRules

Returns the current value of ConditionRules.
(In the database, ConditionRules is stored as text.)



=head2 SetConditionRules VALUE


Set ConditionRules to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ConditionRules will be stored as a text.)


=cut


=head2 ActionRules

Returns the current value of ActionRules.
(In the database, ActionRules is stored as text.)



=head2 SetActionRules VALUE


Set ActionRules to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ActionRules will be stored as a text.)


=cut


=head2 CustomIsApplicableCode

Returns the current value of CustomIsApplicableCode.
(In the database, CustomIsApplicableCode is stored as text.)



=head2 SetCustomIsApplicableCode VALUE


Set CustomIsApplicableCode to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, CustomIsApplicableCode will be stored as a text.)


=cut


=head2 CustomPrepareCode

Returns the current value of CustomPrepareCode.
(In the database, CustomPrepareCode is stored as text.)



=head2 SetCustomPrepareCode VALUE


Set CustomPrepareCode to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, CustomPrepareCode will be stored as a text.)


=cut


=head2 CustomCommitCode

Returns the current value of CustomCommitCode.
(In the database, CustomCommitCode is stored as text.)



=head2 SetCustomCommitCode VALUE


Set CustomCommitCode to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, CustomCommitCode will be stored as a text.)


=cut


=head2 Disabled

Returns the current value of Disabled.
(In the database, Disabled is stored as smallint(6).)



=head2 SetDisabled VALUE


Set Disabled to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Disabled will be stored as a smallint(6).)


=cut


=head2 Template

Returns the current value of Template.
(In the database, Template is stored as int(11).)



=head2 SetTemplate VALUE


Set Template to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Template will be stored as a int(11).)


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
        Description =>
		{read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        ScripCondition =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        ScripAction =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        ConditionRules =>
		{read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        ActionRules =>
		{read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        CustomIsApplicableCode =>
		{read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        CustomPrepareCode =>
		{read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        CustomCommitCode =>
		{read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        Disabled =>
                {read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},
        Template =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
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


### Shredder methods ###

use RT::Shredder::Constants;
use RT::Shredder::Exceptions;
use RT::Shredder::Dependencies;

sub __DependsOn
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Dependencies => undef,
            @_,
           );
    my $deps = $args{'Dependencies'};
    my $list = [];

    my $objs = RTx::AssetTracker::ObjectScrips->new( $self->CurrentUser );
    $objs->LimitToScrip( $self->Id );
    push @$list, $objs;

    $deps->_PushDependencies(
        BaseObject    => $self,
        Flags         => DEPENDS_ON,
        TargetObjects => $list,
        Shredder      => $args{'Shredder'}
    );

    return $self->SUPER::__DependsOn( %args );
}


RT::Base->_ImportOverlays();

1;
