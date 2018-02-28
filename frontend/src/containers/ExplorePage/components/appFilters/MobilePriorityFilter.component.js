import React from 'react';
import PropTypes from 'prop-types';
import { capitalize } from 'utils/format.utils';

const MobilePriorityFilter = ({
  mobilePriority: {
    value,
  },
  panelKey,
  updateFilter,
}) => (
  <li>
    <label className="filter-label">
      Mobile Priority:
    </label>
    <div className="input-group">
      {
        ['low', 'medium', 'high'].map(option => (
          <label key={option} className="explore-checkbox">
            <input
              checked={value.includes(option)}
              onChange={updateFilter('mobilePriority', option, { panelKey })}
              type="checkbox"
              value={option}
            />
            <span>{capitalize(option)}</span>
          </label>
        ))
      }
    </div>
  </li>
);

MobilePriorityFilter.propTypes = {
  mobilePriority: PropTypes.shape({
    value: PropTypes.arrayOf(PropTypes.string),
  }),
  panelKey: PropTypes.string.isRequired,
  updateFilter: PropTypes.func.isRequired,
};

MobilePriorityFilter.defaultProps = {
  mobilePriority: {
    value: [],
  },
};

export default MobilePriorityFilter;