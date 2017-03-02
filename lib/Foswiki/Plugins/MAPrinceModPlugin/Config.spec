# ---+ Extensions
# ---++ MAPrinceModPlugin

# **STRING**
# Path to an image on this wiki to be shown when user has no access to an image.
# <br>When left empty defaults to /System/MAPrinceModPlugin/err.png
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{err} = '';

# **NUMBER**
# Maximum width for <em>width="...px"</em> or <em>style="width:...px</em>
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{MaxWidth} = 680;

# **NUMBER**
# Maximum height for <em>height="...px"</em> or <em>style="height:...px</em>
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{MaxHeight} = 250;

# **BOOLEAN**
# If <em>style="width:..."</em> exceeds <em>MaxHeight</em>, should I add hyphenation?
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{Hyphens} = '1';

# **PATH M**
# Prince executable including complete path.
# Find path with <em>which prince</em>.
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{PrinceCmd} = '/usr/bin/prince';

# **STRING EXPERT**
# Parameters to prince.
# Some special variables will be substetuted:
# <ul><li></li></ul>
# Defaults to <pre>--baseurl %<nop>BASEURL|U% -i html5 -o %<nop>OUTFILE|F% %<nop>INFILE|F% --log=%<nop>ERROR|F% --no-local-files %<nop>CUSTOM|S% %<nop>SCRIPTS|S% %<nop>COOKIES|S%</pre>
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{PrinceParams} = '';

# **STRING**
# These are cutom parameters to be passed to prince.
# Eg. <em>--ssl-cacert=/somedir/mycert.crt</em>
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{CustomParams} = '';

# **PERL**
# Include these scripts when executing prince. Will assume files relative to System's pub-dir.
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{Scripts} = ['MAPrinceModPlugin/maprince.js'];

# **PERL**
# Include these styles when executing prince. Will assume files relative to System's pub-dir.
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{Styles} = ['MAPrinceModPlugin/maprince.css'];

# **STRING**
# Include this jQuery version (defaults to {JQueryPlugin}{JQueryVersion}).
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{jQuery} = '';

# **STRING**
# If you call the export with an invalid domain name (eg. =http://qwiki/=) we will use this domain instead. Enter domain only, no =http://=.Defaults to =127.0.0.1=.
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{altDomain} = '';

1;
