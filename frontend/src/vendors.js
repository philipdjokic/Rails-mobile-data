/* Include all vendor javascript files in the global scope for now
 * Ideally these would be included at the component level
*/

// this order was migrated from the previous index.html file

/*
 * CSS
 *
*/
// require('fontawesome'); // could not get fontawesome to load via npm
// TODO: missing weather-icons but not sure if needed
require('./styles/google-fonts.css'); // This should not be here but migrating and afraid of precedence
require('bootstrap/dist/css/bootstrap.min.css');
require('bootstrap/dist/css/bootstrap-theme.min.css');
require('angularjs-slider/dist/rzslider.min.css');
require('toastr/build/toastr.min.css')
require('angular-bootstrap-lightbox/dist/angular-bootstrap-lightbox.min.css');

/*
 * JS
 *
*/
var Bugsnag = require('bugsnag-js');

/* Previous Bower Components */
window.$ = require('jquery');
window.jQuery = window.$;
require('toastr');
require('angular');
require('angular-route');
// require('underscore'); // hypothesis: this was getting overridden by lodash includes
require('lodash');
require('bootstrap/dist/js/bootstrap');
require('angular-sanitize');
require('jquery-slimscroll');
require('angular-encode-uri');
require('slacktivity');
// require('angularjs-dropdown-multiselect'); // commented out because could not install old version
require('iso-currency');
require('@uirouter/angularjs');
require('angular-bootstrap-lightbox'); // was listed in wrong section
require('angularjs-slider'); // was listed in wrong section
require('satellizer'); // was listed in wrong section
require('angucomplete-alt'); // moved from below for compile issues
require('ng-infinite-scroll'); // moved from below for compile issues
require('moment'); // moved from below for compile issues
require('angular-ui-bootstrap'); // moved from below for compile issues
var mixpanel = require('mixpanel-browser');

/* Custom Scripts */
require('./js/angularjs-dropdown-multiselect.js'); // added
// require('./js/ng-infinite-scroll.min.js');
// require('./js/angucomplete-alt');
// require('./js/extras'); removed because compilation and not sure if needed
// require('./js/other_charts'); removed because compilation and not sure if needed
// require('./js/bootstrap-angular.min.js'); // migrated to npm
// require('./js/moment.min.js'); // migrated to npm


/* Moving extras.js to separate */
require('ng-tags-input');
require('holderjs');

/* Custom configuration */
Bugsnag.apiKey = "3cd7afb86ca3972cfde605c1e0a64a73";
Bugsnag.notifyReleaseStages = ["production"];
if (window && window.location.hostname === 'localhost') {
  Bugsnag.releaseStage = "development";
}

mixpanel.init("6a96c6c2b8cb2ad6de06ad54957b2f2a");
