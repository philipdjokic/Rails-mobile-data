import angular from 'angular';
import mixpanel from 'mixpanel-browser';
import $ from 'jquery';

import 'shared/list-delete/list-delete.directive';
import 'shared/list-delete-selected/list-delete-selected.directive';
import 'shared/export-permissions/export-permissions.directive';

angular.module('appApp').controller("ListCtrl", ["$scope", "$http", "authToken", "$stateParams", "$rootScope", "listApiService", "searchService", "pageTitleService", "$state", "authService", "$location", "csvUtils",
  function($scope, $http, authToken, $stateParams, $rootScope, listApiService, searchService, pageTitleService, $state, authService, $location, csvUtils) {
    $scope.AllSelectedItems = false;
    $scope.NoSelectedItems = false;

    if ($location.url().includes('custom')) {
      pageTitleService.setTitle("MightySignal - Search")
    }

    $scope.load = function() {
      if ($stateParams.listId) {
        $scope.queryInProgress = true;
        listApiService.getList($stateParams.listId).success(function(data) {
          $scope.queryInProgress = false;
          $rootScope.apps = data.results;
          $rootScope.numApps = data.resultsCount;
          $rootScope.currentList = $stateParams.listId;
        }).error(function() {
          $scope.queryInProgress = false;
        });
      }
    };

    $scope.createList = function(listName) {
      listApiService.createNewList(listName).success(function() {
        listApiService.getLists().success(function(data) {
          $rootScope.usersLists = data;
          $('#createNewModal').hide();
          $('.modal-backdrop.fade.in').hide();
        });
      });
    };

    $scope.deleteSelected = function(selectedApps) {
      listApiService.deleteSelected($stateParams.listId, selectedApps).success(function() {
        $rootScope.selectedAppsForList = [];
        $scope.load();
      });
    };

    $scope.deleteList = function() {
      listApiService.deleteList($stateParams.listId).success(function() {
        listApiService.getLists().success(function(data) {
          $rootScope.usersLists = data;
          $state.go('timeline')
          $(".modal-backdrop").remove();
        });
      });
    };

    $scope.exportListToCsv = function() {
      listApiService.exportToCsv($stateParams.listId)
        .success(function (content) {
          csvUtils.downloadCsv(content, 'mightysignal_list')
        });
    };

    $scope.updateCheckboxStatus = function(appId, appType) {
      $rootScope.selectedAppsForList.forEach(function(app) {
        if(app.id == appId && app.type == appType) {
          return true;
        }
      });
      return false;
    };

    $scope.getLastUpdatedDaysClass = function(lastUpdatedDays) {
      return searchService.getLastUpdatedDaysClass(lastUpdatedDays);
    };

    $scope.recordListViewEvent = function(listName, listId) {
      pageTitleService.setTitle(`MightySignal - ${listName}`);

      /* -------- Mixpanel Analytics Start -------- */
      mixpanel.track(
        "List Viewed",
        { "pageType": "Lists",
          "userauthenticated": $rootScope.isAuthenticated,
          "listId": listId,
          "listName": listName }
      );
      /* -------- Mixpanel Analytics End -------- */
    };

    if ($rootScope.isAuthenticated) {
      // authService.userInfo().success(function(data) {
      //   mixpanel.identify(data.email);
      //   mixpanel.people.set({
      //     "$email": data.email,
      //     "jwtToken": authToken.get()
      //   });
      // });

      // Sets user permissions
      // TODO: This needs to be fixed. Calls permissions, getLists, and getList everytime controller is loaded...which is on each view with lists!
      $scope.canViewExports = $rootScope.canViewExports;
      // authService.permissions()
      // .success(function(data) {
      //     $scope.canViewExports = $rootScope.canViewExports;
      // });

      listApiService.getLists().success(function(data) {
        $rootScope.usersLists = data;
      });

      $scope.load();
    }

}]);
