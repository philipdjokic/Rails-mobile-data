import _ from 'lodash';
import getDisplayText from './displayText.utils';

function updateSearchForm(state, action) {
  const { parameter, value } = action.payload;
  switch (parameter) {
    case 'includeTakenDown':
      return {
        ...state,
        includeTakenDown: !state.includeTakenDown,
      };
    case 'fortuneRank':
    case 'mobilePriority':
    case 'headquarters':
    case 'userBase':
      return {
        ...state,
        filters: updateFilters(state.filters, action.payload),
      };
    case 'platform':
      return {
        ...state,
        platform: value,
      };
    case 'resultType':
      return {
        ...state,
        resultType: value,
      };
    case 'sdks':
      return {
        ...state,
        filters: updateFilters(state.filters, action.payload),
      };
    case 'sdkOperator':
      const newState = { ...state };
      newState.filters.sdks.operator = action.payload.value;
      return newState;
    default:
      return state;
  }
}

function updateFilters (filters, { parameter, value, options }) {
  let filter;

  switch (parameter) {
    case 'headquarters':
    case 'fortuneRank':
      filter = updateSingleValueFilter(filters[parameter], parameter, value, options);
      break;
    case 'userBase':
    case 'mobilePriority':
      filter = updateArrayTypeFilter(filters[parameter], parameter, value, options);
      break;
    case 'sdks':
      filter = updateSdkFilter(filters[parameter].filters[options.index], parameter, value, options);
      break;
    default:
      break;
  }

  const newFilters = addFilter(filters, parameter, filter, options);

  return newFilters;
}

function updateArrayTypeFilter (filter, type, value, { panelKey }) {
  const result = {
    panelKey,
    value: [],
  };

  if (filter === undefined) {
    result.value.push(value);
  } else {
    const values = filter.value;
    if (values.includes(value)) {
      _.remove(values, x => x === value);
    } else {
      values.push(value);
    }
    result.value = _.uniq(values);
  }

  result.displayText = getDisplayText(type, result.value);

  return result;
}

function updateSingleValueFilter (filter, type, value, { panelKey }) {
  const result = {
    panelKey,
    value: null,
  };

  if (value && (filter === undefined || value !== filter.value)) {
    result.value = value;
    result.displayText = getDisplayText(type, result.value);
  }

  return result;
}

function updateSdkFilter (filter, type, value, { field }) {
  const newFilter = {
    ...filter,
    [field]: value,
  };

  newFilter.displayText = getDisplayText('sdk', newFilter);

  return newFilter;
}

function addFilter (filters, type, filter, options) {
  const result = { ...filters };

  if (Array.isArray(filter.value) && filter.value.length !== 0) {
    result[type] = filter;
  } else if (!Array.isArray(filter.value) && filter.value) {
    result[type] = filter;
  } else if (type === 'sdks') {
    result.sdks.filters[options.index] = filter;
  } else {
    delete result[type];
  }

  return result;
}

export default updateSearchForm;
