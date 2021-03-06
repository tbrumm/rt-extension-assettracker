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

  RTx::AssetTracker::Port - an AssetTracker Port object

=head1 SYNOPSIS

  use RTx::AssetTracker::Port;

=head1 DESCRIPTION


=head1 METHODS

=cut

use strict;
use warnings;

package RTx::AssetTracker::Port;
use base 'RTx::AssetTracker::Record';

sub Table {'AT_Ports'};

use RTx::AssetTracker::Asset;
use RTx::AssetTracker::IP;

sub IPObj {

    my $self = shift;

    my $ip = RTx::AssetTracker::IP->new( $self->CurrentUser );
    $ip->Load($self->IP);
    return $ip;
}

## Shredder methods ##
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

# Port Transactions
    my $objs = RT::Transactions->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Type', VALUE => 'AddPort' );
    $objs->Limit( FIELD => 'ObjectType', VALUE => 'RTx::AssetTracker::Asset' );
    $objs->Limit( FIELD => 'ObjectId', VALUE => $self->IPObj->Asset );
    $objs->Limit( FIELD => 'NewValue', VALUE => $self->IPObj->IP . ' ' . $self->Transport . ' ' . $self->Port );
    push( @$list, $objs );

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => DEPENDS_ON,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );

    return $self->SUPER::__DependsOn( %args );
}


=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  char(15) 'Transport'.
  char(12) 'Port'.
  int(11) 'IP'.

=cut




sub Create {
    my $self = shift;
    my %args = ( 
                Transport => '',
                Port => '',
                IP => '0',

		  @_);
    $self->SUPER::Create(
                         Transport => $args{'Transport'},
                         Port => $args{'Port'},
                         IP => $args{'IP'},
);

}



=head2 id

Returns the current value of id. 
(In the database, id is stored as int(11).)


=cut


=head2 Transport

Returns the current value of Transport. 
(In the database, Transport is stored as char(15).)



=head2 SetTransport VALUE


Set Transport to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Transport will be stored as a char(15).)


=cut


=head2 Port

Returns the current value of Port. 
(In the database, Port is stored as char(12).)



=head2 SetPort VALUE


Set Port to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Port will be stored as a char(12).)


=cut


=head2 IP

Returns the current value of IP. 
(In the database, IP is stored as int(11).)



=head2 SetIP VALUE


Set IP to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, IP will be stored as a int(11).)


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
        Transport => 
		{read => 1, write => 1, sql_type => 1, length => 15,  is_blob => 0,  is_numeric => 0,  type => 'char(15)', default => ''},
        Port => 
		{read => 1, write => 1, sql_type => 1, length => 12,  is_blob => 0,  is_numeric => 0,  type => 'char(12)', default => ''},
        IP => 
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

RT::Base->_ImportOverlays();

1;
