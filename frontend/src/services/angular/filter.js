import angular from 'angular';
import mixpanel from 'mixpanel-browser';
import moment from 'moment';
import _ from 'lodash';

angular.module('appApp')
  .factory('filterService', ['$rootScope',
    function ($rootScope) {
      return {
        userbaseDisplayText(filter, filterType) {
          let displayName;
          switch (filter.status) {
            case '0':
              displayName = 'User Base';
              break;
            case '1':
              displayName = 'Daily Active Users';
              break;
            case '2':
              displayName = 'Weekly Active Users';
              break;
            case '3':
              displayName = 'Monthly Active Users';
              break;
          }
          return `${filterType} ${displayName}`;
        },
        sdkDisplayText(filter, filterOperation, filterType) {
          let displayName = filterType === 'sdk' ? 'SDK' : 'SDK Category';

          if (filter.status === '0') {
            displayName += ' Installed';
          } else if (filter.status === '1') {
            displayName += ' Uninstalled';
          } else if (filter.status === '2') {
            displayName += ' Never Seen';
          } else {
            displayName += ' Uninstalled or Never Installed';
          }

          if (filter.status === '0' || filter.status === '1') { // Only install or uninstall should show date
            switch (filter.date) {
              case '0':
                displayName += ' Anytime';
                break;
              case '1':
                displayName += ' Less Than 1 Week Ago';
                break;
              case '2':
                displayName += ' Less Than 1 Month Ago';
                break;
              case '3':
                displayName += ' Less Than 3 Months Ago';
                break;
              case '4':
                displayName += ' Less Than 6 Months Ago';
                break;
              case '5':
                displayName += ' Less Than 9 Months Ago';
                break;
              case '6':
                displayName += ' Less Than 1 Year Ago';
                break;
              case '7':
                displayName += ` Between ${moment(filter.dateRange.from).format('L')} and ${moment(filter.dateRange.until).format('L')}`;
                break;
              case '8':
                displayName += ' Between 1 Week and 1 Month Ago';
                break;
              case '9':
                displayName += ' Between 1 Months and 3 Months Ago';
                break;
              case '10':
                displayName += ' Between 3 Months and 6 Months Ago';
                break;
              case '11':
                displayName += ' Between 6 Months and 9 Months Ago';
                break;
              case '12':
                displayName += ' Between 9 Months and 1 Year Ago';
                break;
            }
          }

          return `${filterOperation} ${displayName}`;
        },
        locationDisplayText(filter, filterType) {
          let displayName = '';

          if (filter.status === '0') {
            displayName = `Headquartered in${displayName}`;
          } else if (filter.status === '1') {
            displayName = `Only available in${displayName}`;
          } else if (filter.status === '2') {
            displayName = `Available in${displayName}`;
          } else if (filter.status === '3') {
            displayName = `Not Available in${displayName}`;
          }

          return `${filterType} ${displayName}`;
        },
        hasFilter(parameter, value) {
          for (let i = $rootScope.tags.length - 1; i >= 0; i--) {
            if (($rootScope.tags[i].parameter === parameter) && (!value || $rootScope.tags[i].value === value)) {
              return true;
            }
          }
          return false;
        },
        changeFilter(parameter, oldValue, value, newDisplayText) {
          for (let i = $rootScope.tags.length - 1; i >= 0; i--) {
            // only check for value if value exists
            if ($rootScope.tags[i].parameter === parameter && this.tagsAreEqual($rootScope.tags[i], oldValue)) {
              const possible = ['status', 'date', 'state', 'id', 'name', 'dateRange'];
              for (let y = 0; y < possible.length; y++) {
                if (value[possible[y]]) {
                  $rootScope.tags[i].value[possible[y]] = value[possible[y]];
                }
              }
              if (value.state && value.state !== '0') {
                $rootScope.tags[i].text = `${newDisplayText}: ${value.state}, ${$rootScope.tags[i].value.name}`;
              } else {
                $rootScope.tags[i].text = `${newDisplayText}: ${$rootScope.tags[i].value.name}`;
              }
              break;
            }
          }
        },
        clearAllSdkCategoryTags() {
          _.remove($rootScope.tags, tag => tag.parameter.includes('sdkCategoryFilters'));
        },
        removeFilter(parameter, value) {
          for (let i = $rootScope.tags.length - 1; i >= 0; i--) {
            // only check for value if value exists
            if ($rootScope.tags[i].parameter === parameter && (value === null || this.tagsAreEqual($rootScope.tags[i], value))) {
              $rootScope.tags.splice(i, 1);
            }
          }
        },
        tagsAreEqual(tag1, tag2) {
          const value = tag1.value;
          return (value === tag2) || (typeof value.id !== 'undefined' && typeof tag2.id !== 'undefined' && value.id === tag2.id && value.status === tag2.status && value.date === tag2.date && value.state === tag2.state);
        },
        addFilter(parameter, value, displayName, limitToOneFilter, customName, trackInMixpanel = true) {
          /* -------- Mixpanel Analytics Start -------- */
          if (trackInMixpanel) {
            const mixpanelProperties = {};
            mixpanelProperties.parameter = parameter;
            mixpanelProperties[parameter] = value;
            mixpanel.track(
              'Filter Added',
              mixpanelProperties,
            );
          }
          /* -------- Mixpanel Analytics End -------- */

          let duplicateTag = false;
          let oneTagUpdated = false;
          const self = this;
          $rootScope.tags.forEach((tag) => {
            // Determine if tag is a duplicate (for tags with objects for values)
            if (tag.value.id !== undefined && tag.parameter === parameter && self.tagsAreEqual(tag, value)) {
              duplicateTag = true;
            }

            // Determine if tag is a duplicate for normal tags (with non-object values)
            if (tag.parameter === parameter && tag.value === value) {
              duplicateTag = true;
            }

            if (limitToOneFilter && !duplicateTag) {
              // If replacing pre existing tag of limitToOneFilter = true category
              if (tag.parameter === parameter) {
                tag.value = value;
                tag.text = `${displayName}: ${customName || value}`;
                oneTagUpdated = true;
              }
            }
          });

          if (limitToOneFilter && !duplicateTag && !oneTagUpdated) {
            // If first tag of limitToOneFilter = true category
            $rootScope.tags.push({
              parameter,
              value,
              text: `${displayName}: ${customName || value}`,
            });
          }
          const complexFilters = ['sdkFiltersOr', 'sdkFiltersAnd', 'sdkCategoryFiltersOr', 'sdkCategoryFiltersOr', 'locationFiltersAnd', 'locationFiltersOr', 'userbaseFiltersOr', 'userbaseFiltersAnd'];
          if (!limitToOneFilter && (!duplicateTag || complexFilters.indexOf(parameter) > -1) || $rootScope.tags.length < 1) {
            $rootScope.tags.push({
              parameter,
              value,
              text: `${displayName}: ${customName || value}`,
            });
          }
        },
      };
    },
  ]);
