import React from 'react';
import PropTypes from 'prop-types';

import { capitalize } from 'utils/format.utils';

const MobilePriorityCell = ({
  mobilePriority,
}) => {
  if (typeof mobilePriority === 'number') {
    const ratings = ['low', 'medium', 'high'];
    mobilePriority = ratings[mobilePriority];
  }

  return (
    <div>
      {mobilePriority ? (
        <span>
          <i className={`fa fa-circle status-${mobilePriority}`} />
          {` ${capitalize(mobilePriority)}`}
        </span>
      ) : <span className="invalid">Not available</span>}
    </div>
  );
};

MobilePriorityCell.propTypes = {
  mobilePriority: PropTypes.oneOfType([PropTypes.string, PropTypes.number]).isRequired,
};

export default MobilePriorityCell;
