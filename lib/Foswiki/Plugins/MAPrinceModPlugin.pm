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

package Foswiki::Plugins::MAPrinceModPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();
use Foswiki::Plugins ();
use Foswiki::Sandbox;

use File::Temp;


our $VERSION = '1.1';

our $RELEASE = "1.1";

our $SHORTDESCRIPTION = 'Print with prince.';

our $NO_PREFS_IN_TOPIC = 1;

use constant TRACE => 0;

our $baseTopic;
our $baseWeb;

sub initPlugin {
    ( $baseTopic, $baseWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerRESTHandler(
        'getFile', \&_restGetFile,
        authenticate => 1,
        http_allow => 'GET',
        validate => 0
    );

    Foswiki::Func::registerRESTHandler(
        'princeGet', \&_restPrinceGet,
        authenticate => 0,
        http_allow => 'GET',
        validate => 0
    );

    return 1;
}

sub completePageHandler {
    #my($html, $httpHeaders) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    my $contenttype = $query->param("contenttype") || 'text/html';

    # is this a pdf view?
    return unless $contenttype eq "application/pdf";

    # don't print login-boxes
    my $wikiName = Foswiki::Func::getWikiName();
    return unless Foswiki::Func::checkAccessPermission( 'VIEW', $wikiName, undef, $baseTopic, $baseWeb );

    # scripts we will add to the html
    # Unfortunalty prince does not seem support window.JSON, so we add lots of
    # script tags.
    my @scripts = ();

    # remove left-overs
    $_[0] =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;

    # Get base path to images
    my $url = Foswiki::Func::getUrlHost();
    $url =~ s#^https?://www\.#http://#; # workaround for optional www
    $url =~ s#^https://#http://#;


    # Get user for permissions
    my $user = $Foswiki::Plugins::SESSION->{user};
    $user = Foswiki::Func::getWikiName($user);

    # TODO: move these into maprince.js
    # remove <p></p> from tables as they are usually not desired
    $_[0] =~ s#<td([^>]*)>\n(<p></p>|<p\s*/>)#<td$1>\n#g;

    # limit widths and heights
    my $maxWidth = $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{MaxWidth} || 680;
    my $maxHeight = $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{MaxHeight} || 250;
    my $hyphens = $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{Hypens} || 0;
    push @scripts, "<script class='MAPrinceModPluginMaxWidth' type='text/plain'>$maxWidth</script>";
    push @scripts, "<script class='MAPrinceModPluginMaxHeight' type='text/plain'>$maxHeight</script>";
    push @scripts, "<script class='MAPrinceModPluginHyphens' type='text/plain'>$hyphens</script>";

    # remove NAMEFILTER, since it is not properly escaped and we do not need it for printing
    $_[0] =~ s#"NAMEFILTER":\s?".*"#"NAMEFILTER": ""#;

    # mappings for the princeGet rest handler
    # This is to allow ACL checks with the current user.
    # The actual rewriting will take place in maprince.js.
    #    * 'mapTo' points the the rest handler
    #    * 'mapFrom' are all the urls that are to be rewritten
    #    * 'mapExceptions' these are regexes with exceptions, they are applied
    #       after 'mapFrom' has been stripped.
    #
    # Note: We must not rewrite System, because many plugins have directory
    # structures that do not map to a subweb, thus XSendFieleContrib will fail.
    my $mapTo = Foswiki::Func::getScriptUrlPath('MAPrinceModPlugin', 'princeGet', 'rest');
    my $mapFrom = [
        Foswiki::Func::getScriptUrl(undef, undef, 'xsendfile'),
        Foswiki::Func::getScriptUrlPath(undef, undef, 'xsendfile'),
        Foswiki::Func::getScriptUrl(undef, undef, 'viewfile'),
        Foswiki::Func::getScriptUrlPath(undef, undef, 'xsendfile'),
        Foswiki::Func::getPubUrlPath(undef, undef, undef, absolute => 1 ),
        Foswiki::Func::getPubUrlPath(undef, undef, undef, absolute => 0 ),
    ];
    my $mapExceptions = ["^/$Foswiki::cfg{SystemWebName}/"]; # this might become configurable
    push @scripts, map{ "<script class='MAPrinceModPluginMapFrom' type='text/plain'>$_</script>" } @$mapFrom;
    push @scripts, map{ "<script class='MAPrinceModPluginMapException' type='text/plain'>$_</script>" } @$mapExceptions;
    push @scripts, "<script class='MAPrinceModPluginMapTo' type='text/plain'>$mapTo</script>";

    # add scripts
    $_[0] =~ s#(</head[^>]*>)#join("\n", @scripts).$1#e;

    # create temp files
    my $modactmpDir = Foswiki::Func::getWorkArea( 'MAPrinceModPlugin' );
    my $htmlFile = new File::Temp(DIR => $modactmpDir, SUFFIX => '.html', UNLINK => (TRACE?0:1));
    my $errorFile = new File::Temp(DIR => $modactmpDir, SUFFIX => '.log', UNLINK => (TRACE?0:1));
    my $modacpdfFile = new File::Temp(DIR => $modactmpDir, TEMPLATE => "${wikiName}XXXXXXXX", SUFFIX => '.pdf', UNLINK => 0);
    die unless $modacpdfFile =~ m#^$modactmpDir/$wikiName(.*)\.pdf$#;
    my $token = $1;
    my $tokenFile = new File::Temp(DIR => $modactmpDir, TEMPLATE => "${token}XXXX", SUFFIX => '.token', UNLINK => 1);

    # create token and cookies
    my $cgi = $Foswiki::Plugins::SESSION->getCGISession();
    my $security = ($cgi ? $cgi->id() : '') . $token . rand();
    my $cuid = Foswiki::Func::getCanonicalUserID();
    my $tokenContent = "User:$cuid\nSecurity:$security";
    if($Foswiki::UNICODE) {
        $tokenContent = Foswiki::encode_utf8($tokenContent);
    }
    print $tokenFile $tokenContent;
    close $tokenFile;

    my $domain = Foswiki::Func::getUrlHost();
    $domain =~ s#^https?://##;
    # if this is not a valid domain, we need to rewrite
    unless ($domain =~ m#\.#) {
        my $altDomain = $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{altDomain} || '127.0.0.1';
        $_[0] =~ s#(\<base href="https?://(?:www\.)?)$domain#$1$altDomain#g;
        $domain = $altDomain;
    }

    my $cookieSecurity = "security=$security;Domain=$domain";
    my $cookieToken = "tokenFile=$tokenFile;Domain=$domain";

    # create html file
    my $content = $_[0];
    if ($Foswiki::cfg{Site}{CharSet} !~ /^utf-?8$/i) {
        $content = Encode::encode('UTF-8', Encode::decode($Foswiki::cfg{Site}{CharSet} || 'iso-8859-1', $content));
    }

    if($Foswiki::UNICODE) {
        $content = Foswiki::encode_utf8($content);
    }

    print $htmlFile $content;

    # create prince command
    my $session = $Foswiki::Plugins::SESSION;
    my $baseurl = $domain;
    my $princeCmd = $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{PrinceCmd} || '/usr/bin/prince';
    $princeCmd .= ' ' . ($Foswiki::cfg{Extensions}{MAPrinceModPlugin}{PrinceParams} || ' --baseurl %BASEURL|U% -i html5 -o %OUTFILE|F% %INFILE|F% --log=%ERROR|F% --no-local-files %STYLES% %SCRIPTS% %COOKIES%');
    $princeCmd .= ' ' . $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{CustomParams} if $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{CustomParams};

    # include jquery
    my $cmdscripts = $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{Scripts} || [];
    my $version = $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{jQuery} || $Foswiki::cfg{JQueryPlugin}{JQueryVersion};
    unshift @$cmdscripts, "JQueryPlugin/$version.js";

    #  put scripts into cmd
    my $system = "$Foswiki::cfg{PubDir}/$Foswiki::cfg{SystemWebName}/";
    my %scriptHash = ();
    foreach my $i (0 .. $#$cmdscripts) {
        my $script = $system . ($cmdscripts->[$i] =~ s#^(?:\Q$system\E|/)##r);
        $scriptHash{"SCRIPT$i"} = $script;
    }
    my $scriptString = join(' ', map{"--script=\%$_|F\%"} sort keys %scriptHash);
    $princeCmd =~ s#%SCRIPTS%#$scriptString#;

    #  put styles into cmd
    my %styleHash = ();
    my $styles = $Foswiki::cfg{Extensions}{MAPrinceModPlugin}{Styles} || [];
    for(my $i = 0; $i < scalar @$styles; $i++) {
        my $style = $system . ($styles->[$i] =~ s#^(?:\Q$system\E|/)##r);
        $styleHash{"STYLE$i"} = $style;
    }
    my $styleString = join(' ', map{"-s \%$_|F\%"} sort keys %styleHash);
    $princeCmd =~ s#%STYLES%#$styleString#;

    # put cookies into cmd
    my $cookieString = "--cookie=%COOKIESECURITY|S% --cookie=%COOKIETOKENFILE|S%";
    $princeCmd =~ s#%COOKIES%#$cookieString#;

    if(TRACE) {
        my ($output, $exit) = Foswiki::Sandbox->sysCommand(
            "echo '$princeCmd'",
            BASEURL => $baseurl,
            OUTFILE => $modacpdfFile->filename,
            INFILE => $htmlFile->filename,
            ERROR => $errorFile->filename,
            COOKIESECURITY => $cookieSecurity,
            COOKIETOKENFILE => $cookieToken,
            %scriptHash,
            %styleHash,
        );
        Foswiki::Func::writeWarning("cmd (-+ escapings): $output");
    }

    # execute
    my ($output, $exit) = Foswiki::Sandbox->sysCommand(
        $princeCmd,
        BASEURL => $baseurl,
        OUTFILE => $modacpdfFile->filename,
        INFILE => $htmlFile->filename,
        ERROR => $errorFile->filename,
        COOKIESECURITY => $cookieSecurity,
        COOKIETOKENFILE => $cookieToken,
        %scriptHash,
        %styleHash,
    );

    local $/ = undef;

    my $error = '';
    if ($exit) {
        $error = <$errorFile>;
    }

    if ($exit) {
        my $html = $_[0];
        my $line = 1;
        $html = '00000: '.$html;
        $html =~ s/\n/"\n".(sprintf "\%05d", $line++).": "/ge;
        throw Error::Simple("execution of prince failed ($exit): \n\n$error\n\n$html");
    }

    my $attachment = $query->param('attachment') || 0;

    my $redirect = Foswiki::Func::getScriptUrl(
        'MAPrinceModPlugin', 'getFile', 'rest',
        token => $token,
        wikiname => $wikiName,
        attachment => $attachment,
        basetopic => $baseTopic,
        baseweb => $baseWeb
    );
    Foswiki::Func::redirectCgiQuery( undef, $redirect );
}

sub maintenanceHandler {
    Foswiki::Plugins::MaintenancePlugin::registerCheck("MAPrinceModPlugin:trace", {
        name => "MAPrinceModPlugin TRACE",
        description => "MAPrinceModPlugin's TRACE (debug mode) is active",
        check => sub {
            if(TRACE) {
                return {
                    result => 1,
                    priority => $Foswiki::Plugins::MaintenancePlugin::WARN,
                    solution => "Please edit Foswiki/Plugins/MAPrinceModPlugin.pm and set TRACE to 0."
                }
            } else {
                return { result => 0 };
            }
        }
    });
    Foswiki::Plugins::MaintenancePlugin::registerCheck("MAPrinceModPlugin:workarea", {
        name => "Temporary files for MAPrinceModPlugin",
        description => "MAPrinceModPlugin's workarea containts garbage",
        check => sub {
            my $result = { result => 0 };
            my $modactmpDir = Foswiki::Func::getWorkArea( 'MAPrinceModPlugin' );
            my @files = <$modactmpDir/*.{html,log,pdf}>;
            if ( scalar @files ) {
                $result->{result} = 1;
                $result->{priority} = $Foswiki::Plugins::MaintenancePlugin::WARN;
                $result->{solution} = "Please delete leftover pdf/log/html files in $modactmpDir";
            }
            return $result;
        }
    });
    Foswiki::Plugins::MaintenancePlugin::registerCheck("GenPDFPrincePlugin enabled", {
        name => "GenPDFPrincePlugin enabled",
        description => "GenPDFPrincePlugin is no longer supported.",
        check => sub {
            my $result = { result => 0 };
            if ( $Foswiki::cfg{Plugins}{GenPDFPrincePlugin}{Enabled} ) {
                $result->{result} = 1;
                $result->{priority} = $Foswiki::Plugins::MaintenancePlugin::ERROR;
                $result->{solution} = "Please disable GenPDFPrincePlugin in configure";
            }
            return $result;
        }
    });
}

sub _restPrinceGet {
    my ($session, $verb, $subject, $response) = @_;
    my $query = Foswiki::Func::getCgiQuery();
    my $request = $session->{request};
    my $shortPath;

    my $writeError = sub {
        my ($shortPath, $error) = @_;

        my $user = Foswiki::Func::getCanonicalUserID();

        Foswiki::Func::writeWarning("user $user wants to get $shortPath: $error");
        $response->status(401);
        $response->print("401 - see logs\n");
    };

    # remove our rest handler from the path
    $shortPath = $request->pathInfo();
    if($Foswiki::UNICODE) {
#        $shortPath = Foswiki::decode_utf8($shortPath);
    }
    Foswiki::Func::writeWarning("princeGet $shortPath") if TRACE;
    $shortPath =~ s#.*?/princeGet/#/#;
    $request->pathInfo($shortPath);

    # become user associated with token
    my $tokenFile = $request->cookie('tokenFile');
    my $security = $request->cookie('security');
    my $user;

    unless($tokenFile) {
        $writeError->($shortPath, "Missing tokenFile cookie");
        return;
    }

    unless(-e $tokenFile) {
        $writeError->($shortPath, "tokenFile no longer on disk");
        return;
    }

    my $tokenContent = Foswiki::Func::readFile($tokenFile);
    if($tokenContent =~ m#^Security:\Q$security\E$#m && $tokenContent =~ m#^User:(.*)#m) {
        $user = $1;
    } else {
        $writeError->($shortPath, "Token/Security does not match");
        return;
    }

    unless($user) {
        $writeError->($shortPath, "No user found in tokenFile");
        return;
    }

    local $Foswiki::Plugins::SESSION->{user} = $user;

    # return the file
    return Foswiki::Contrib::XSendFileContrib::xsendfile($session, $request, $response);
}

sub _restGetFile {
    my ($session, $verb, $subject, $response) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    my $token = $query->param('token');
    my $baseTopic = $query->param('basetopic') || 'unknown';
    my $baseWeb = $query->param('baseweb') || 'unknown';
    my $wikiName = $query->param('wikiname');

    unless ($wikiName eq Foswiki::Func::getWikiName()) {
        my $heading = Foswiki::Func::expandCommonVariables('%MAKETEXT{"User mismatch for printout."}%');
        my $message = Foswiki::Func::expandCommonVariables('%MAKETEXT{"The PDF file you are trying to access was not created by you. This may have been caused by the browser cache. Please create a new PDF."}%');
        throw Foswiki::OopsException(
            'oopsgeneric',
            web => $baseWeb,
            topic => $baseTopic,
            params => [ $heading, $message ]
        );
    }

    my $modactmpDir = Foswiki::Func::getWorkArea( 'MAPrinceModPlugin' );
    my $filename = "$modactmpDir/$wikiName$token.pdf";
    unless (-e $filename) {
        my $heading = Foswiki::Func::expandCommonVariables('%MAKETEXT{"Printout no longer available."}%');
        my $message = Foswiki::Func::expandCommonVariables('%MAKETEXT{"The PDF file you are trying to access is no longer available on the server. This may have been caused by the browser cache. Please create a new PDF."}%');
        throw Foswiki::OopsException(
            'oopsgeneric',
            web => $baseWeb,
            topic => $baseTopic,
            params => [ $heading, $message ]
        );
    }

    my $file; # note: can not use Foswiki::Func::readFile, because I need binary stuff
    unless (open ( $file, "<", $filename )) {
        my $heading = Foswiki::Func::expandCommonVariables('%MAKETEXT{"Error opening printout."}%');
        my $message = Foswiki::Func::expandCommonVariables('%MAKETEXT{"There was an error opening the PDF file. This is most likely due to a misconfiguration."}%');
        throw Foswiki::OopsException(
            'oopsgeneric',
            web => $baseWeb,
            topic => $baseTopic,
            params => [ $heading, $message ]
        );
    };
    binmode($file, ":raw");

    local $/;
    my $pdf = <$file>;

    close $file;
    unlink $filename;

    $response->body($pdf);
    $response->headers({
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => (($query->param("attachment"))?'attachment':'inline') . ";filename=$baseTopic.pdf"
        });
    return;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
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
