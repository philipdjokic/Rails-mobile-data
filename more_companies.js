// var page = require('webpage').create();
// page.open('https://angel.co/companies', function() {
//   page.includeJs("http://code.jquery.com/jquery-1.11.1.min.js", function() {
//
//     console.log("JQuery loaded")
//
//     page.evaluate(function() {
//       // $("button.more").click()
//
//       // console.log("evaluate")
//
//       var moreLength = 0;
//
//       do {
//
//
//
//       } while (moreLength != 0);
//
//       var more = $(".more");
//       more.click();
//
//       // console.log("moreButton: " + moreButton)
//     });
//
//     console.log("moreButton: " + moreButton)
//
//     console.log("will exit")
//     phantom.exit()
//   });
// });

//This is an example of how to scrape the web using PhantomJS and jQuery:
//source: http://snippets.aktagon.com/snippets/534-How-to-scrape-web-pages-with-PhantomJS-and-jQuery
//http://phantomjs.org/
 
 var page = new WebPage(),
     url = 'https://angel.co/companies',
     stepIndex = 0;
 
 /**
  * From PhantomJS documentation:
  * This callback is invoked when there is a JavaScript console. The callback may accept up to three arguments: 
  * the string for the message, the line number, and the source identifier.
  */
 page.onConsoleMessage = function (msg, line, source) {
     console.log('console> ' + msg);
 };
 
 /**
  * From PhantomJS documentation:
  * This callback is invoked when there is a JavaScript alert. The only argument passed to the callback is the string for the message.
  */
 page.onAlert = function (msg) {
     console.log('alert!!> ' + msg);
 };
 
 // Callback is executed each time a page is loaded...
 page.open(url, function (status) {
   if (status === 'success') {
     
     console.log("open success");
     window.setTimeout(function () {
       // State is initially empty. State is persisted between page loads and can be used for identifying which page we're on.
       console.log('============================================');
       console.log('Step "' + stepIndex + '"');
       console.log('============================================');
 
       // Inject jQuery for scraping (you need to save jquery-1.6.1.min.js in the same folder as this file)
       // page.injectJs('jquery-1.6.1.min.js');
       page.includeJs("http://code.jquery.com/jquery-1.11.1.min.js");
 
       // Our "event loop"
       if(!phantom.state){
         // initialize();
         clickMore();
       } else {
         phantom.state();
       } 
 
       // Save screenshot for debugging purposes
       // page.render("more_companies_screenshots/step" + stepIndex++ + ".png");
     }, 10000); // Change timeout as required to allow sufficient time 
   }
 });
 
 function clickMore() {
   page.evaluate(function() {
     // console.log("I AM HERE")
     
     var moreLength = 0;
       
     var more = $(".more");
     
     $('.value').find(".website").each(function() {
        // console.log($(this).html());
        console.log($(this).text());
     });
     
     moreLength = more.length;
     
     more.click();
     
     console.log("clicked more");
     
     // setTimeout(function(){
     //   $('.value').find(".website").each(function() {
     //      console.log($(this).text());
     //   });
     // }, 5000);
     
     var foundSitesForThisRound = false;
     var waitingForMore = false;
     var run = 0;
     
     var interval = setInterval(function(){
       
       if(foundSitesForThisRound == false)
       {
         console.log("***********************************Run " + run);
         run ++;
         
         var more = $(".more");
       
         $('.value').find(".website").each(function() {
            console.log($(this).text());
         });
       
         foundSitesForThisRound = true;
       
         more.click();
         
         waitingForMore = true;
       }
       
       if(waitingForMore == true)
       {
         var more2 = $(".more");
       
         var moreText = more2.text()
       
         console.log(moreText);
       
         if(moreText.indexOf("More") == -1)
         {
           console.log("Loading...")
         }
         else
         {
           console.log("FOUND MORE LINK")
           
           waitingForMore = false;
           foundSitesForThisRound = false;
           // clearInterval(interval);
         }
       }
       
       
       }, 1000);
   });
   
   // phantom.exit();
 }
 
 function finish() {
   phantom.exit();
 }