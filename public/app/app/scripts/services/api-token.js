'use strict';

angular.module('appApp')
  .factory('apiTokenService', ["$http", "loggitService", function ($http, loggitService) {
    return {
      getApiTokens: function (id) {
        return $http({
          method: 'GET',
          url: `${API_URI_BASE}api/admin/get_api_tokens`,
          params: { account_id: id }
        })
      },
      generateToken: function (id, rateLimit, rateWindow) {
        return $http({
          method: 'POST',
          url: `${API_URI_BASE}api/admin/generate_api_token`,
          params: {
            account_id: id,
            rate_limit: rateLimit,
            rate_window: rateWindow
          }
        })
      },
      deleteToken: function (id) {
        return $http({
          method: 'PUT',
          url: `${API_URI_BASE}api/admin/delete_api_token`,
          params: { token_id: id }
        })
      },
      updateToken: function (id, data) {
        return $http({
          method: 'POST',
          url: `${API_URI_BASE}api/admin/update_api_token`,
          params: {
            id,
            data
          }
        })
      },
      toast: function (type) {
        switch (type) {
          case 'token-create-success':
            return loggitService.logSuccess("Token was created successfully.");
          case 'token-create-failure':
            return loggitService.logError("Error! Something went wrong while creating your token.")
          case 'token-update-success':
            return loggitService.logSuccess("Token was updated successfully.");
          case 'token-update-failure':
            return loggitService.logError("Error! Something went wrong while updating your token.")
          case 'token-delete-success':
            return loggitService.logSuccess("Token was deleted successfully.");
          case 'token-delete-failure':
            return loggitService.logError("Error! Something went wrong while deleting your token.")
        }
      }
    }
  }])