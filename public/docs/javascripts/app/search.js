!function(t){"use strict";function e(){$("h1, h2").each(function(){var t=$(this),e=t.nextUntil("h1, h2");h.add({id:t.prop("id"),title:t.text(),body:e.text()})})}function i(){r=$(".content"),a=$(".dark-box"),l=$(".search-results"),$("#input-search").on("keyup",n)}function n(t){if(s(),l.addClass("visible"),27===t.keyCode&&(this.value=""),this.value){var e=h.search(this.value).filter(function(t){return t.score>1e-4});e.length?(l.empty(),$.each(e,function(t,e){var i=document.getElementById(e.ref);l.append("<li><a href='#"+e.ref+"'>"+$(i).text()+"</a></li>")}),o.call(this)):(l.html("<li></li>"),$(".search-results li").text('No Results Found for "'+this.value+'"'))}else s(),l.removeClass("visible")}function o(){this.value&&r.highlight(this.value,c)}function s(){r.unhighlight(c)}var r,a,l,c=($(t),{element:"span",className:"search-highlight"}),h=new lunr.Index;h.ref("id"),h.field("title",{boost:10}),h.field("body"),h.pipeline.add(lunr.trimmer,lunr.stopWordFilter),$(e),$(i)}(window);