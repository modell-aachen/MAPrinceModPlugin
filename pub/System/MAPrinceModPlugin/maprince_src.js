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

    // style workarounds

    // remove nowraps (we like nowraps and CKEditor is rather generous)
    $('[nowrap]').each(function() {
        $(this).removeAttr('nowrap');
    });
    $('[style*="white-space:nowrap"]').each(function() {
        $(this).css('white-space', '');
    });

    // clean url params in anchors as prince can't generate proper xrefs otherwise
    var anchorRegex = new RegExp(/\?.*#/);
    $('[href*="#"]').each(function() {
        var $this = $(this);
        var href = $this.attr('href');
        if(anchorRegex.test(href)) {
            href = href.replace(anchorRegex, '#');
            $this.attr('href', href);
        }
    });

    // limit width
    // (not of images, because we have style sheets for them)
    var maxWidth = $('script.MAPrinceModPluginMaxWidth').text();
    var hyphens = $('script.MAPrinceModPluginHyphens').text();
    var widthRegex = /((?:^|;)width\s*:\s*)(\d+)\s*(px|;|$)/;
    $('[style*="width"]:not(img,svg)').each(function() {
        var $this = $(this);
        // this crashes prince
        // var width = $this.css('width');
        // width = width.replace(/px$/, '');
        // if(/\D/.test(width)) return;
        var style = $this.attr('style');
        var m = widthRegex.exec(style);
        if(!m) return;
        var width = m[2];

        if(new Number(width) > new Number(maxWidth)) { // prince needs explicit conversion
            // $this.css('width', maxWidth);
            // if(hyphens) $this.css('hyphens', 'auto');
            style = style.replace(widthRegex, m[1] + maxWidth + m[3]);
            if(hypens) style = 'hypens:auto;' + style;
            $this.attr('style', style);
        }
    });
    $('[width]:not(img,svg)').each(function() {
        var $this = $(this);
        var width = $this.attr('width');
        width = width.replace(/px$/, '');
        if(/\D/.test(width)) return;
        if(new Number(width) > new Number(maxWidth)) { // conversion for prince again
            $this.attr('width', maxWidth);
            if(hyphens) $this.css('hyphens', 'auto');
        }
    });

    // limit height
    var maxHeight = $('script.MAPrinceModPluginMaxHeight').text();
    $('[height]').filter('table,tr,td,th').each(function() {
        // CKEditor puts some invalid heights on table rows, to ensure that
        // they have _some_ height. We need to translate this into min-height,
        // or the layouter will mess up.
        var $this = $(this);
        var height = $this.attr('height');
        height = height.replace(/(?:;|px)$/, ''); // remove some nonsense
        if(/\D/.test(height)) return;
        $this.removeAttr('height');
        if(new Number(height) < new Number(maxHeight)) { // conversion for prince
            $this.attr('min-height', height);
            Log.warning('setting min-height ' + height);
        }
    });
    var heightRegex = /((?:^|;)height\s*:\s*)(\d+)\s*(?:px)?(;|$)/;
    $('[style*="height"]').filter('table,tr,td,th').each(function(){
        var $this = $(this);
        // crashes prince again...
        // var height = $this.css('height');
        // height = height.replace(/px$/, '');
        // if(/\D/.test(height)) return;
        var style = $this.attr('style');
        var m = heightRegex.exec(style);
        if(!m) return;
        var height = m[2];
        // $this.css('height', '');
        style = style.replace(heightRegex, m[3]);
        if(new Number(height) < new Number(maxHeight)) {
            style += 'min-height:' + height;
        }
        $this.attr('style', style);
    });

    // rewrite 'src' attributes to princeGet rest handler

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

