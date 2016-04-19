jQuery(function() {
    var $ = jQuery;

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
});

