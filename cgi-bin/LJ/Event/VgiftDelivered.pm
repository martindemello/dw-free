#!/usr/bin/perl
#
# LJ::Event::VgiftDelivered
#
# Event for delivering a virtual gift
#
# Authors:
#      Jen Griffin <kareila@livejournal.com>
#
# Copyright (c) 2012 by Dreamwidth Studios, LLC.
#
# This program is free software; you may redistribute it and/or modify it under
# the same terms as Perl itself. For a copy of the license, please reference
# 'perldoc perlartistic' or 'perldoc perlgpl'.

package LJ::Event::VgiftDelivered;
use strict;

use base 'LJ::Event';
use Carp qw(croak);
use DW::VirtualGiftTransaction;

sub new {
    my ( $class, $u, $transid ) = @_;

    croak 'Not an LJ::User' unless LJ::isu( $u );
    croak 'Invalid transaction' unless $transid && $transid =~ /^\d+$/;

    return $class->SUPER::new( $u, $transid );
}

sub arg_list {
    return ( "Transaction id" );
}

# access args
sub transid { return $_[0]->arg1 }

sub trans {
    my ( $self ) = @_;
    my %args = ( user => $self->u, id => $self->transid );
    $self->{trans} = DW::VirtualGiftTransaction->load( %args )
        unless $self->{trans};
    return $self->{trans};
}

sub vgift { return $_[0]->trans->{vgift} }


# inbox message content
sub as_string {
    my ( $self ) = @_;
    my $trans = $self->trans or return LJ::Lang::ml( 'event.vgift.notfound' );

    my $from = $trans->from_text;
    return LJ::Lang::ml( "event.vgift.delivery.content", { fromuser => $from } );
}

sub as_html {
    my ( $self ) = @_;
    my $trans = $self->trans or return LJ::Lang::ml( 'event.vgift.notfound' );

    my $from = $trans->from_html;
    my $img = $self->vgift->img_small_html;
    my $ret = "<div class='pkg'>";
    $ret .= "<div style='width: auto; float: left; margin: 0 1em;'>$img</div>"
        if $img;
    $ret .= '<div>';
    $ret .= LJ::Lang::ml( "event.vgift.delivery.content", { fromuser => $from } );
    $ret .= '</div></div>';

    return $ret;
}

sub as_html_actions {
    my ( $self ) = @_;
    my $trans = $self->trans or return '';
    my $u = $self->u;

    my $url = $trans->url;
    my $index = $u->journal_base . '/vgifts/';

    my $ret = "<div class='actions'>";
    $ret .= LJ::Lang::ml( 'event.vgift.delivery.actions',
                     { aopts1 => "href='$url'", aopts2 => "href='$index'" } );
    $ret .= "</div>\n";

    return $ret;
}

sub content_summary { return $_[0]->as_string }

sub content {
    my ( $self ) = @_;
    my $trans = $self->trans or return LJ::Lang::ml( 'event.vgift.notfound' );

    my $ret = '<p>';
    $ret .= '<blockquote>' . $trans->{reason} . '</blockquote></p><p>'
        if $trans->{reason};
    $ret .= LJ::Lang::ml( "event.vgift.delivery.msg",
                     { num_days => $LJ::VGIFT_EXPIRE_DAYS } ) . "</p>\n";
    $ret .= $self->as_html_actions;

    return $ret;
}

# contents for plaintext email
sub as_email_string {
    my ( $self, $u ) = @_;
    my $trans = $self->trans;
    my $from = $trans->from_text;
    my $anon = $trans->is_anonymous
               ?  LJ::Lang::ml( 'shop.item.vgift.anonymous',
                                { sitenameshort => $LJ::SITENAMESHORT } )
               : '';

    return LJ::Lang::ml( 'shop.email.vgift.body.text',
        {
            sitenameshort => $LJ::SITENAMESHORT,
            sitename => $LJ::SITENAME,
            touser   => $u->display_name,
            fromuser => $anon || $from,
            accept   => $trans->url,
        } ) . "\n\n";
}

sub as_email_html {
    my ( $self, $u ) = @_;
    my $trans = $self->trans;
    my $from = $trans->from_html;
    my $anon = $trans->is_anonymous
               ?  LJ::Lang::ml( 'shop.item.vgift.anonymous',
                                { sitenameshort => $LJ::SITENAMESHORT } )
               : '';

    return LJ::Lang::ml( 'shop.email.vgift.body.html',
        {
            sitenameshort => $LJ::SITENAMESHORT,
            sitename => $LJ::SITENAME,
            touser   => $u->ljuser_display,
            fromuser => $anon || $from,
            accept   => $trans->url,
        } ) . "\n\n";
}

sub as_email_subject {
    my $self = $_[0];

    return LJ::Lang::ml( 'shop.email.vgift.subject',
        {
            sitenameshort => $LJ::SITENAMESHORT,
        } );
}

# subscriptions are always on, can't be turned off
sub is_common { 1 }

sub is_visible { 1 }

sub always_checked { 1 }

sub subscription_as_html {
    my ( $class, $subscr ) = @_;
    return LJ::Lang::ml( 'event.vgift.delivery' );
}

# override parent class subscription methods to always return
# a subscription object for the user - copied from LJ::Event::XPostSuccess
sub subscriptions {
    my ( $self, %args ) = @_;
    my $cid   = delete $args{'cluster'};  # optional
    my $limit = delete $args{'limit'};    # optional
    croak("Unknown options: " . join(', ', keys %args)) if %args;
    croak("Can't call in web context") if LJ::is_web_context();

    my @subs;
    my $u = $self->u;
    return unless $cid == $u->clusterid;

    my $row = { userid  => $self->u->id,
                ntypeid => LJ::NotificationMethod::Inbox->ntypeid, # Inbox
              };

    push @subs, LJ::Subscription->new_from_row($row);

    push @subs, eval { $self->SUPER::subscriptions(cluster => $cid,
                                                   limit   => $limit) };

    return @subs;
}

sub get_subscriptions {
    my ( $self, $u, $subid ) = @_;

    unless ($subid) {
        my $row = { userid  => $u->{userid},
                    ntypeid => LJ::NotificationMethod::Inbox->ntypeid, # Inbox
                  };

        return LJ::Subscription->new_from_row($row);
    }

    return $self->SUPER::get_subscriptions($u, $subid);
}


1;
