# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

=pod

---+ package Foswiki::Plugins::MAPrinceModPlugin

=cut


package Foswiki::Plugins::MAPrinceModPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package. This should always be in the format
# $Rev: 9772 (2010-10-27) $ so that Foswiki can determine the checked-in status of the
# extension.
our $VERSION = '1.0';

our $RELEASE = "1.0";

our $SHORTDESCRIPTION = 'Modifies page contents for printing with GenPDFPrincePlugin.';

our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    return 1;
}

sub completePageHandler {
  #my($html, $httpHeaders) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $contenttype = $query->param("contenttype") || 'text/html';

  # is this a pdf view?
  return unless $contenttype eq "application/pdf";

  # Get base path to images
  my $url = Foswiki::Func::getUrlHost();

  # Get user for permissions
  my $user = $Foswiki::Plugins::SESSION->{user};
  $user = Foswiki::Func::getWikiName($user);

  # XXX Das sind alles nur Workarounds
  # remove all those plentiful nowraps (we like wraps)
  $_[0] =~ s/white-space: nowrap;//g;
  $_[0] =~ s/nowrap="nowrap"//g;
  # remove <p></p> from tables as they are usually not desired
  $_[0] =~ s#<td([^>]*)>\n(<p></p>|<p\s*/>)#<td$1>\n#g;
  # limit width
  $_[0] =~ s#(style=['"][^'"]*)(width:\s*)(\d+)(?:px)?\s*(;|['"])#limitStyleWidth($1,$2,$3,$4)#ige;
  $_[0] =~ s#(width=['"])(\d+)(?:px)?;?(['"])#limitWidth('', $1,$2,$3)#ige;

  #$_[0] =~ s#(width|height):\s*\d+(px|%);##g;
  #$_[0] =~ s#style="\s*"##g;

  # replace image tags
  $_[0] =~ s/\<img(.*?)(\/?)\>/rewriteImgTag($1, $url, $user, $2)/ige;

  # remove (large) predefined heights from tables
  $_[0] =~ s#(\<table[^>]*)(height=["'])(\d+)(["'])#limitHeight($1,$2,$3,$4)#ige;
  $_[0] =~ s#(\<table[^>]*)(style=["']([^'"]*)height:\s*["'])(\d+)(["'])#limitHeight($1,$2,$3,$4)#ige;

  # remove NAMEFILTER, since it is not properly escaped and we do not need it for printing
  $_[0] =~ s#"NAMEFILTER":\s?".*"#"NAMEFILTER": ""#;
}

sub limitHeight {
    my ($tag, $open, $height, $close) = @_;

    my $maxHeight = $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{MaxHeight} || 250;

    if($height > 250) { # XXX arbitrary number
        return $tag;
    } else {
        return "$tag$open$height$close";
    }
}

sub limitWidth {
    my ($tag, $open, $width, $close) = @_;

    my $maxWidth = $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{MaxWidth} || 680;

    if($width > $maxWidth) {
        return "$tag$open${maxWidth}px$close";
    } else {
        return "$tag$open${width}px$close";
    }
}


sub limitStyleWidth {
  my ($tag, $open, $width, $close) = @_;

  my $maxWidth = $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{MaxWidth} || 680;
  my $hyphens = ($Foswiki::cfg{Extensions}{MAPrinceModPlugin}{Hypens})?'hyphens:auto':'hyphens:none';

  if($width > $maxWidth) {
    return "$tag$open${maxWidth}px;$hyphens$close";
  }
  return "$tag$open${width}px$close";
}

sub rewriteImgTag {
  my $tagContents = $_[0];
  my $url = $_[1];
  my $user = $_[2];
  my $end = $_[3] || '';

  my $url2 = $url;
  $url2 =~ s#http://www\.#http://#; # workaround for optional www

  # Check if image is from our Foswiki
  if($tagContents =~ m#$url|$url2|/pub/#) {

     # Ok, lets find out which Topic/Web...
     # first find Foswiki-Url, then /bin or /bin/viewfile or plain /, then save Web in $1, finally store rest in $2. Deliminator is "' or ? (don't want cgi-part)
     $tagContents =~ m#(?:$url|$url2)?/(?:pub/|bin/viewfile/)(.*?)/([^'"?]*)#;
     my $web = $1;
     my $topic = $2;
     # now cut the image-File from topic
     # everything between / and ? is Image. Rest will be removed.
     $topic =~ s#/([^?]*).*$##;     # this comment is for vim
     my $image = $1;

     # now check if user may view this picture
     # However anyone may view System
     my $hasAccess = $web eq 'System' || Foswiki::Func::checkAccessPermission('VIEW',$user,'',$topic,$web,undef);


     # if we have access write a new image-url pointing to local directory
     # but forbit linking to local files other than from this plugin
     if($hasAccess && not $tagContents =~ m#file://#i ) {
       $tagContents =~ s#src=(["']).*?["']#src=\"file://$Foswiki::cfg{PubDir}/$web/$topic/$image\"#g;
     } else {
       # Insert "Access Denied" image
       my $deniedImage = $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{err} || "/System/MAPrinceModPlugin/err.png";
       $tagContents =~ s#src=(["']).*?["']#src=\"file://$Foswiki::cfg{PubDir}$deniedImage\"#g;
     }
  }
  return "<img$tagContents$end>";
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
