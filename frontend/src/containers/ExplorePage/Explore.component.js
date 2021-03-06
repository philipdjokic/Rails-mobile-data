import React from 'react';
import PropTypes from 'prop-types';

import ExploreTableContainer from './containers/ExploreTable.container';
import SavedSearchContainer from './containers/SavedSearch.container';
import SearchFormContainer from './containers/SearchForm.container';

const Explore = ({
  existingId,
  queryId,
  populateFromQueryId,
  shouldFetchCountries,
  requestAvailableCountries,
  shouldFetchCategories,
  requestCategories,
  shouldFetchSdkCategories,
  requestSdkCategories,
  shouldFetchRankingsCountries,
  requestRankingsCountries,
  shouldFetchPermissions,
  requestPermissions,
  shouldFetchAppPermissionsOptions,
  requestAppPermissionsOptions,
  shouldFetchGeoOptions,
  requestGeoOptions,
}) => {
  if (queryId && (!existingId || (queryId !== existingId))) {
    populateFromQueryId(queryId);
  }

  if (shouldFetchCountries) requestAvailableCountries();
  if (shouldFetchRankingsCountries) requestRankingsCountries();
  if (shouldFetchCategories) requestCategories();
  if (shouldFetchSdkCategories) requestSdkCategories();
  if (shouldFetchAppPermissionsOptions) requestAppPermissionsOptions();
  if (shouldFetchGeoOptions) requestGeoOptions();
  if (shouldFetchPermissions) requestPermissions();

  return (
    <div className="page explore-page">
      <h4 className="page-title explore-title">
        Explore V2
        {' '}
        <span className="beta-flag">NEW</span>
      </h4>
      <SavedSearchContainer />
      <SearchFormContainer />
      <div className="table-container">
        <div className="scroll-anchor" />
        <div className="table-wrapper">
          <ExploreTableContainer />
        </div>
      </div>
    </div>
  );
};

Explore.propTypes = {
  populateFromQueryId: PropTypes.func.isRequired,
  queryId: PropTypes.string,
  existingId: PropTypes.string,
  shouldFetchCountries: PropTypes.bool.isRequired,
  requestAvailableCountries: PropTypes.func.isRequired,
  shouldFetchRankingsCountries: PropTypes.bool.isRequired,
  requestRankingsCountries: PropTypes.func.isRequired,
  shouldFetchCategories: PropTypes.bool.isRequired,
  requestCategories: PropTypes.func.isRequired,
  shouldFetchSdkCategories: PropTypes.bool.isRequired,
  requestSdkCategories: PropTypes.func.isRequired,
  requestPermissions: PropTypes.func.isRequired,
  shouldFetchPermissions: PropTypes.bool.isRequired,
  shouldFetchAppPermissionsOptions: PropTypes.bool.isRequired,
  requestAppPermissionsOptions: PropTypes.func.isRequired,
  shouldFetchGeoOptions: PropTypes.bool.isRequired,
  requestGeoOptions: PropTypes.func.isRequired,
};

Explore.defaultProps = {
  queryId: '',
  existingId: null,
};

export default Explore;
