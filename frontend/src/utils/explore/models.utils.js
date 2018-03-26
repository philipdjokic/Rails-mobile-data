import { headerNames } from 'Table/redux/column.models';

// map between frontend display fields and backend field
// place sort field at beginning of the list
export const selectMap = {
  [headerNames.APP]: [
    'name',
    'id',
    'current_version',
    'icon_url',
    'taken_down',
    'app_identifier',
    'first_scanned_date',
    'price_category',
    'original_release_date',
  ],
  [headerNames.COUNTRIES_AVAILABLE_IN]: ['countries_available_in'],
  [headerNames.FIRST_SEEN_ADS]: ['ad_summaries'],
  [headerNames.LAST_SEEN_ADS]: ['ad_summaries'],
  [headerNames.LAST_UPDATED]: ['current_version_release_date'],
  [headerNames.MOBILE_PRIORITY]: ['mobile_priority'],
  [headerNames.PLATFORM]: ['platform'],
  [headerNames.PUBLISHER]: ['publisher'],
  [headerNames.RATING]: ['all_version_rating'],
  [headerNames.RATINGS_COUNT]: ['all_version_ratings_count'],
  [headerNames.USER_BASE]: ['user_base'],
  [headerNames.AD_NETWORKS]: ['ad_summaries'],
  [headerNames.CATEGORY]: ['categories'],
};

export const sortMap = {
  [headerNames.APP]: { field: 'name', object: 'app' },
  [headerNames.LAST_UPDATED]: { field: 'current_version_release_date', object: 'app' },
  [headerNames.PUBLISHER]: { field: 'name', object: 'publisher' },
  [headerNames.RATING]: { field: 'all_version_rating', object: 'app' },
  [headerNames.RATINGS_COUNT]: { field: 'all_version_ratings_count', object: 'app' },
};

export const isAppFilter = filter => Object.keys(appFilterKeys).includes(filter);
export const isPubFilter = filter => Object.keys(publisherFilterKeys).includes(filter);
export const isAdIntelFilter = filter => Object.keys(adIntelFilterKeys).includes(filter);
export const getQueryFilter = filter => Object.assign({}, appFilterKeys, publisherFilterKeys, adIntelFilterKeys)[filter];

export const appFilterKeys = {
  availableCountries: 'available_in',
  mobilePriority: 'mobile_priority',
  userBase: 'user_base',
  price: 'free',
  inAppPurchases: 'in_app_purchases',
  adNetworkCount: 'count_advertising_networks',
  ratingsCount: 'all_version_ratings_count',
  rating: 'all_version_rating',
  releaseDate: 'released',
};

export const publisherFilterKeys = {
  fortuneRank: 'fortune_rank',
  headquarters: 'country_code',
};

export const adIntelFilterKeys = {
  creativeFormats: '',
};
