import React from 'react';
import PropTypes from 'prop-types';
import { Panel } from 'react-bootstrap';
import { panelFilterCount } from 'utils/explore/general.utils';

import AvailableCountriesFilter from '../appFilters/AvailableCountriesFilter.component';
import CategoriesFilter from '../appFilters/CategoriesFilter.component';
import FilterCountLabel from '../FilterCountLabel.component';
import InAppPurchaseFilter from '../appFilters/InAppPurchaseFilter.component';
import MobilePriorityFilter from '../appFilters/MobilePriorityFilter.component';
import PriceFilter from '../appFilters/PriceFilter.component';
import UserbaseFilter from '../appFilters/UserbaseFilter.component';

const AppFilterPanel = ({
  filters,
  filters: {
    appCategory,
    mobilePriority,
    userBase,
  },
  handleSelect,
  panelKey,
  ...rest
}) => (
  <Panel eventKey={panelKey}>
    <Panel.Heading onClick={handleSelect(panelKey)}>
      <Panel.Title>
        App Details
        <FilterCountLabel count={panelFilterCount(filters, panelKey)} />
        <i className="fa fa-angle-down pull-right" />
      </Panel.Title>
    </Panel.Heading>
    <Panel.Body collapsible>
      <ul className="panel-filters list-unstyled">
        <MobilePriorityFilter mobilePriority={mobilePriority} panelKey={panelKey} {...rest} />
        <PriceFilter />
        <InAppPurchaseFilter />
        <AvailableCountriesFilter />
        <CategoriesFilter filter={appCategory} {...rest} />
        <UserbaseFilter panelKey={panelKey} userBase={userBase} {...rest} />
      </ul>
    </Panel.Body>
  </Panel>
);

AppFilterPanel.propTypes = {
  filters: PropTypes.object.isRequired,
  handleSelect: PropTypes.func,
  panelKey: PropTypes.string.isRequired,
};

AppFilterPanel.defaultProps = {
  handleSelect: () => {},
};

export default AppFilterPanel;