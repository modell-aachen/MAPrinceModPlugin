jQuery(function() {
    var $ = jQuery;

    // allow pagebreaks in tables
    //    * iserted by CKEditorPlugin
    //    * will put a 'page-break-after' on the corresponding tr/td

    $('div>span:contains("PAGEBREAK")').each(function() {
        var $this = $(this);

        var $allowBreak = $this.parents('tr,td');
        if(!$allowBreak.length) return;

        var $div = $this.closest('div');

        var pagebreak = /\bpage-break-after\s*:\s*([a-z]*)/.exec($div.attr('style')); // can not get via $div.css(...) in prince
        if(!(pagebreak && pagebreak[1] !== 'avoid')) return;

        //$allowBreak.each(function(){$(this).css('page-break-inside', 'auto');});
        $allowBreak.css('page-break-inside', 'auto');
    });

    // rewrite 'src' attributes to rest handler

    // location of rest-handler
    var $mapTo = $('script.MAPrinceModPluginMapTo');
    if($mapTo.length != 1) return; // do not allow more, possably an exploit
    var mapTo = $mapTo.text();

    // things we want to rewrite
    var regexes = [];
    $('script.MAPrinceModPluginMapFrom').each(function() {
        regexes.push(new RegExp('^' + $(this).text()));
    });

    // things we do not want to rewrite
    var exceptions = [];
    $('script.MAPrinceModPluginMapException').each(function() {
        exceptions.push(new RegExp($(this).text()));
    });

    // do the rewrite
    $('[src]').each(function() {
        var $this = $(this);
        var src = $this.attr('src');
        $.each(regexes, function(idx, regex) {
            if(regex.test(src)) {
                var newSrc = src.replace(regex, '');
                for(var i = 0; i < exceptions.length; i++) {
                    if(exceptions[i].test(newSrc)) return;
                }
                $this.attr('src', mapTo + newSrc);
            }
        });
    });
});

