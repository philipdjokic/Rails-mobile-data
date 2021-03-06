import angular from 'angular';
import _ from 'lodash';

import 'components/export-permissions/export-permissions.directive';
import 'components/ad-intel-tab/ad-intel-tab.directive';
import 'components/facebook-carousel/facebook-carousel.directive';
import 'AngularUtils/app.utils';
import 'AngularUtils/creative-gallery.utils';
import 'AngularMixpanel/app.mixpanel.service';
import 'AngularService/app.service';
import 'AngularService/ad-intelligence.service';
import 'AngularService/newsfeed';
import MightyQueryService from 'services/mightyQuery.service';
import { addAdIds } from 'utils/app.utils';
import { attachGetCompanyContactsLoader } from 'utils/contact.utils';
import './components/rankings-tab/rankings-tab.directive';

angular
  .module('appApp')
  .controller('AppController', AppController);

AppController.$inject = [
  'appService',
  '$state',
  '$stateParams',
  'loggitService',
  'newsfeedService',
  'listApiService',
  'contactService',
  'pageTitleService',
  'sdkLiveScanService',
  '$rootScope',
  '$sce',
  '$window',
  'authService',
  '$auth',
  'authToken',
  '$timeout',
  '$scope',
  'appMixpanelService',
  'csvUtils',
  'adIntelService',
  'appUtils',
];

function AppController (
  appService,
  $state,
  $stateParams,
  loggitService,
  newsfeedService,
  listApiService,
  contactService,
  pageTitleService,
  sdkLiveScanService,
  $rootScope,
  $sce,
  $window,
  authService,
  $auth,
  authToken,
  $timeout,
  $scope,
  appMixpanelService,
  csvUtils,
  adIntelService,
  appUtils,
) {
  const app = this;

  app.activeSlide = 0;
  app.appFetchComplete = false;
  app.companyContactFilter = '';
  app.contactFetchComplete = false;
  app.currentContactsPage = 1;
  app.linkedinTooltip = $sce.trustAsHtml('LinkedIn profile <span class="fa fa-external-link"></span>');
  app.permissionText = 'Not Available';
  app.queryDataLoaded = false;
  app.tabs = [
    { title: 'General Information', index: 0, route: 'app.info' },
    { title: 'Ad Intelligence', index: 1, route: 'app.ad-intelligence' },
    { title: 'Rankings', index: 2, route: 'app.rankings' },
  ];
  app.userInfo = {};

  // Bound Functions
  app.addToList = addToList;
  app.authenticateSalesforce = authenticateSalesforce;
  app.calculateDaysAgo = sdkLiveScanService.calculateDaysAgo;
  app.exportContactsToCsv = exportContactsToCsv;
  app.followApp = followApp;
  app.getCompanyContacts = getCompanyContacts;
  app.getContactEmail = getContactEmail;
  app.handleTagButtonClick = handleTagButtonClick;
  app.onLinkedinButtonClick = onLinkedinButtonClick;
  app.openAppStorePage = openAppStorePage;
  app.resetAppData = resetAppData;
  app.trackCompanyContactsRequest = appMixpanelService.trackCompanyContactsRequest;
  app.trackCopiedEmail = appMixpanelService.trackCopiedEmail;
  app.trackCrunchbaseClick = appMixpanelService.trackCrunchbaseClick;
  app.trackLinkedinContactClick = appMixpanelService.trackLinkedinContactClick;
  app.trackSalesforceModalOpen = appMixpanelService.trackSalesforceModalOpen;
  app.trackTabClick = appMixpanelService.trackTabClick;

  activate();

  function activate() {
    getApp()
      .then(() => {
        getCompanyContacts();
        getSalesforceData();
        setUpSalesforce();
        getMightyQueryData();
        pageTitleService.setTitle(app.name);
        appMixpanelService.trackAppPageView(app);
      });
  }

  function addToList (list) {
    const selectedApp = [{
      id: app.id,
      type: app.type,
    }];
    listApiService.addSelectedTo(list, selectedApp)
      .success(() => {
        loggitService.logSuccess('App was added to list successfully.');
        $rootScope.selectedAppsForList = [];
      }).error(() => {
        loggitService.logError('Error! Something went wrong while adding to list.');
      });
    $rootScope.addSelectedToDropdown = '';
  }

  function authenticateSalesforce (provider) {
    $auth.authenticate(provider, { token: authToken.get() })
      .then(() => {
        $scope.sfUserConnected = true;
        getSalesforceData();
      })
      .catch((response) => {
        $scope.sfUserConnected = false;
        alert(response.data.error);
      });
  }

  function exportContactsToCsv (filter) {
    contactService.exportContactsToCsv(app.platform, app.publisher.id, filter, app.publisher.name)
      .then((content) => {
        csvUtils.downloadCsv(content, 'contacts');
      });
  }

  function followApp (id, action) {
    const follow = {
      id,
      type: app.platform === 'ios' ? 'IosApp' : 'AndroidApp',
      name: app.name,
      action,
      source: 'appDetails',
    };
    newsfeedService.follow(follow)
      .success((data) => {
        app.following = data.is_following;
        if (data.is_following) {
          loggitService.logSuccess('You will now see updates for this app on your Timeline');
        } else {
          loggitService.log('You will stop seeing updates for this app on your Timeline');
        }
      });
  }

  function getApp () {
    return appService.getApp($stateParams.platform, $stateParams.id)
      .then((data) => {
        Object.assign(app, data);
        app.facebookAds = addAdIds(data.facebookAds);
        app.appFetchComplete = true;
        $scope.appAvailable = data.appAvailable;
        if ($stateParams.platform === 'ios') {
          app.ratings = appUtils.filterUnavailableCountries(data.ratings, data.appStores.availableIn);
          app.rating = appUtils.formatRatings(app.ratings);
          app.userBases = appUtils.filterUnavailableCountries(data.userBases, data.appStores.availableIn);
          $scope.appAvailableCountries = data.appStores.availableIn.map(country => country.country_code);
        }
      })
      .catch(() => { throw Error('Failed App Page Load'); });
  }

  function getCompanyContacts(filter) {
    attachGetCompanyContactsLoader(
      app,
      contactService.getCompanyContacts(app.platform, app.publisher.id, filter, app.currentContactsPage)
    )
  };

  function getContactEmail (contact) {
    contact.isLoading = true;
    const clearbitId = contact.clearbitId;
    contactService.getContactEmail(clearbitId)
      .then((data) => {
        appMixpanelService.trackEmailRequest(data.email, clearbitId);
        contact.email = data.email;
        contact.isLoading = false;
      });
  }

  function getMightyQueryData () {
    MightyQueryService.getAppInfo(app.platform, app.id)
      .then(({ data }) => {
        app.queryDataLoaded = true;
        app.newcomers = data.newcomers;
        app.rankings = data.rankings.charts;
        app.permissions = data.permissions ? _.sortBy(data.permissions, x => x.display) : data.permissions;
        if (app.permissions) {
          if (!app.permissions.length) {
            app.permissionText = 'None';
          } else {
            app.permissionText = `${app.permissions.slice(0, 2).map(x => x.display).join(', ')}`;
          }
        }
      });
  }

  function getSalesforceData () {
    authService.userInfo()
      .success((data) => {
        app.userInfo.email = data.email;
        app.userInfo.salesforceName = data.salesforce_name;
        app.userInfo.salesforceImageUrl = data.salesforce_image_url;
      });
  }

  function handleTagButtonClick () {
    appService.tagAsMajorApp(app.id, app.platform)
      .then((data) => {
        app.isMajorApp = data.isMajorApp;
      });
  }

  function onLinkedinButtonClick (linkType) {
    contactService.goToLinkedIn(linkType, app.publisher.name, 'app');
  }

  function openAppStorePage () {
    const page = app.platform === 'ios' ? app.appStoreLink : `https://play.google.com/store/apps/details?id=${app.appIdentifier}`;
    $window.open(page);
  }

  function resetAppData () {
    loggitService.log('Resetting app data. The page will refresh shortly.');
    appService.resetAppData(app.id)
      .then(() => {
        $timeout(() => {
          $state.reload();
        }, 5000);
      });
  }

  function setUpSalesforce () {
    authService.accountInfo()
      .success((data) => {
        app.salesforceSettings = data.salesforce_settings;
      });
  }
}
