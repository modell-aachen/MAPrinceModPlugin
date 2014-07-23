# ---+ Extensions
# ---++ MAPrinceModPlugin
# **STRING**
# Path to an image on this wiki to be shown when user has no access to an image.
# <br>When left empty defaults to /System/MAPrinceModPlugin/err.png
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{err} = '';
# **NUMBER**
# Maximum width for <em>width="...px"</em> or <em>style="width:...px</em>
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{MaxWidth} = 680;
# **BOOLEAN**
# If <em>style="width:..."</em> exceeds <em>MaxHeight</em>, should I add hyphenation?
$Foswiki::cfg{Extensions}{MAPrinceModPlugin}{Hyphens} = '1';
1;
