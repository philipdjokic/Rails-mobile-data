import angular from 'angular';
import _ from 'lodash';

import 'shared/ad-intelligence/creative-gallery/creative-gallery.directive'
import 'shared/ad-intelligence/ad-network-panel/ad-network-panel.directive'
import 'shared/ad-intelligence/ad-summary-panel/ad-summary-panel.directive'
import '../scripts/directives/fallback-src.directive'
import '../scripts/directives/format-icon.directive'
import './publisher.utils'

angular
  .module('appApp')
  .controller('PublisherAdIntelligenceController', PublisherAdIntelligenceController);

PublisherAdIntelligenceController.$inject = [
  '$state',
  '$stateParams',
  'publisherService',
  'appMixpanelService',
  '$scope',
  'publisherUtils'
];

function PublisherAdIntelligenceController(
  $state,
  $stateParams,
  publisherService,
  appMixpanelService,
  $scope,
  publisherUtils
) {
  var pubAdIntel = this;

  pubAdIntel.adDataFetchComplete = false;
  pubAdIntel.apps = {}
  pubAdIntel.checkIfAdSource = checkIfAdSource;
  pubAdIntel.creativePageSize = 8;
  pubAdIntel.error = false;
  pubAdIntel.getCreatives = publisherService.getPublisherCreatives;
  pubAdIntel.hasAdData = false;
  pubAdIntel.numApps = 0;
  pubAdIntel.sortedApps = [];

  activate();

  function activate() {
    if ($scope.$parent.$parent.publisher.facebookOnly) {
      $state.go('publisher.info', { platform: $stateParams.platform, id: $stateParams.id })
    } else {
      pubAdIntel.id = $stateParams.id
      pubAdIntel.platform = $stateParams.platform
      getAdIntelData()
    }
  }

  function checkIfAdSource (id, sources) {
    return sources.some(source => source.id === id)
  }

  function getAdIntelData () {
    return publisherService.getAdIntelData($stateParams.platform, $stateParams.id)
      .then(function(response) {
        const data = response.data
        if (!_.isEmpty(data)) {
          const results = publisherUtils.formatAdData(data)
          Object.assign(pubAdIntel, results)
          pubAdIntel.apps = data;
          pubAdIntel.numApps = Object.keys(data).length
          pubAdIntel.sortedApps = sortApps(data)
          pubAdIntel.hasAdData = true;
        }
        pubAdIntel.adDataFetchComplete = true;
      })
      .catch(error => {
        pubAdIntel.error = true;
        pubAdIntel.adDataFetchComplete = true;
      })
  }

  function sortApps (apps) {
    const appsArray = []
    for (const id in apps) {
      const app = apps[id]
      app.id = id
      appsArray.push(app)
    }
    return _.sortBy(appsArray, app => app.last_seen_ads_date).reverse()
  }
}
