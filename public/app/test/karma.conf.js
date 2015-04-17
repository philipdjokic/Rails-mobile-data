// Karma configuration
// http://karma-runner.github.io/0.12/config/configuration-file.html
// Generated on 2015-04-09 using
// generator-karma 0.9.0

module.exports = function(config) {
  'use strict';

  config.set({
    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: true,

    // base path, that will be used to resolve files and exclude
    basePath: '../',

    // testing framework to use (jasmine/mocha/qunit/...)
    frameworks: ['jasmine'],

    // list of files / patterns to load in the browser
    files: [
      // bower:js
      'bower_components/jquery/dist/jquery.js',
      'bower_components/angular/angular.js',
      'bower_components/angular-animate/angular-animate.js',
      'bower_components/angular-route/angular-route.js',
      'bower_components/underscore/underscore.js',
      'bower_components/lodash/dist/lodash.compat.js',
      'bower_components/angular-wizard/dist/angular-wizard.js',
      'bower_components/angular-ui-tree/dist/angular-ui-tree.js',
      'bower_components/bootstrap/dist/js/bootstrap.js',
      'bower_components/rangy/rangy-core.min.js',
      'bower_components/rangy/rangy-cssclassapplier.min.js',
      'bower_components/rangy/rangy-selectionsaverestore.min.js',
      'bower_components/rangy/rangy-serializer.min.js',
      'bower_components/textAngular/src/textAngular.js',
      'bower_components/textAngular/src/textAngular-sanitize.js',
      'bower_components/textAngular/src/textAngularSetup.js',
      'bower_components/angular-sanitize/angular-sanitize.js',
      'bower_components/angular-bootstrap/ui-bootstrap-tpls.js',
      'bower_components/chartjs/Chart.js',
      'bower_components/raphael/raphael.js',
      'bower_components/mocha/mocha.js',
      'bower_components/morrisjs/morris.js',
      'bower_components/flot/jquery.flot.js',
      'bower_components/jquery.sparkline.build/dist/jquery.sparkline.js',
      'bower_components/slimScroll/jquery.slimscroll.min.js',
      // endbower
      'app/scripts/**/*.js',
      'test/mock/**/*.js',
      'test/spec/**/*.js'
    ],

    // list of files / patterns to exclude
    exclude: [
    ],

    // web server port
    port: 8080,

    // Start these browsers, currently available:
    // - Chrome
    // - ChromeCanary
    // - Firefox
    // - Opera
    // - Safari (only Mac)
    // - PhantomJS
    // - IE (only Windows)
    browsers: [
      'PhantomJS'
    ],

    // Which plugins to enable
    plugins: [
      'karma-phantomjs-launcher',
      'karma-jasmine'
    ],

    // Continuous Integration mode
    // if true, it capture browsers, run tests and exit
    singleRun: false,

    colors: true,

    // level of logging
    // possible values: LOG_DISABLE || LOG_ERROR || LOG_WARN || LOG_INFO || LOG_DEBUG
    logLevel: config.LOG_INFO,

    // Uncomment the following lines if you are using grunt's server to run the tests
    // proxies: {
    //   '/': 'http://localhost:9000/'
    // },
    // URL root prevent conflicts with the site root
    // urlRoot: '_karma_'
  });
};
