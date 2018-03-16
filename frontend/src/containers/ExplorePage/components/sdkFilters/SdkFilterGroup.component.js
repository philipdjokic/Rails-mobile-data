import React from 'react';
import PropTypes from 'prop-types';
import { Select, DatePicker, Icon, Spin, Tooltip, TreeSelect } from 'antd';
import { capitalize } from 'utils/format.utils';
import ExploreService from 'services/explore.service';
import { formatCategorySdksTree, updateCategorySdks, formatCategorySdksValue } from 'utils/explore/general.utils';

const Option = Select.Option;
const RangePicker = DatePicker.RangePicker;

class SdkFilterGroup extends React.Component {
  constructor (props) {
    super(props);
    this.fetchSdkOptions = this.fetchSdkOptions.bind(this);
    this.updateSdkFilter = this.updateSdkFilter.bind(this);
    this.lastFetchId = 0;

    this.state = {
      sdkOptions: [],
      fetching: false,
    };
  }

  fetchSdkOptions (value) {
    if (value === '') {
      return;
    }

    this.lastFetchId += 1;
    const fetchId = this.lastFetchId;
    this.setState({ sdkOptions: [], fetching: true });
    ExploreService().getSdkAutocompleteResults(this.props.platform, value)
      .then((response) => {
        if (fetchId !== this.lastFetchId) {
          return;
        }
        const sdks = response.data.results.map(x => ({ ...x, platform: x.platform.toLowerCase() }));

        this.setState({ sdkOptions: sdks, fetching: false });
      });
  }

  updateSdkFilter (values) {
    const { updateFilter, index, filter } = this.props;
    const options = filter.sdks.concat(this.state.sdkOptions);
    const newSdks = values.map((val) => {
      const [id, platform, type] = val.key.split(' ');
      const sdk = options.find(x => x.id === parseInt(id, 10) && x.platform === platform && x.type === type);
      if (type === 'sdkCategory' && !sdk.includedSdks) {
        sdk.includedSdks = sdk.sdks;
      }
      return { ...sdk, ...val, label: `${sdk.name} (${capitalize(sdk.platform)})` };
    });
    const newFilter = {
      ...filter,
      sdks: newSdks,
    };
    updateFilter('sdks', newFilter, { index })();
  }

  render () {
    const {
      canDelete,
      deleteFilter,
      duplicateSdkFilter,
      filter,
      filter: {
        dateRange,
        dates,
        eventType,
        sdks,
        operator,
      },
      index,
      updateFilter,
    } = this.props;

    const { sdkOptions, fetching } = this.state;

    const showDateOptions = !['never-seen', 'is-installed', 'is-not-installed'].includes(eventType);
    const showDatePicker = !['never-seen', 'is-installed', 'is-not-installed'].includes(eventType) && dateRange === 'custom';
    const treeData = formatCategorySdksTree(sdks);
    const treeValues = formatCategorySdksValue(sdks);

    return (
      <div className="sdk-filter-group">
        <div className="options-group">
          <div className="action-items">
            { canDelete && <Icon onClick={() => deleteFilter('sdks', index)} type="delete" /> }
            <Tooltip title="Duplicate filter">
              <Icon onClick={duplicateSdkFilter(index)} type="copy" />
            </Tooltip>
          </div>
          <Select
            onChange={(value) => {
              const newFilter = {
                ...filter,
                eventType: value,
              };
              updateFilter('sdks', newFilter, { index })();
            }}
            size="small"
            style={{
              width: '180px',
            }}
            value={eventType}
          >
            <Option value="install">Installed</Option>
            <Option value="uninstall">Uninstalled</Option>
            <Option value="never-seen">Never Seen</Option>
            <Option value="is-installed">Currently Installed</Option>
            <Option value="is-not-installed">Currently Not Installed</Option>
          </Select>
          {
            showDateOptions && (
              <Select
                onChange={(value) => {
                  const newFilter = {
                    ...filter,
                    dateRange: value,
                  };
                  updateFilter('sdks', newFilter, { index })();
                }}
                size="small"
                style={{
                  width: '160px',
                }}
                value={dateRange}
              >
                <Option value="anytime">Anytime</Option>
                <Option value="week">Last Week</Option>
                <Option value="month">Last Month</Option>
                <Option value="three-months">Last Three Months</Option>
                <Option value="six-months">Last Six Months</Option>
                <Option value="year">Last Year</Option>
                <Option value="custom">Custom Date Range</Option>
              </Select>
            )
          }
          { showDatePicker && (
            <RangePicker
              onChange={(value) => {
                const newFilter = {
                  ...filter,
                  dates: value,
                };
                updateFilter('sdks', newFilter, { index })();
              }}
              size="small"
              style={{ width: '225px' }}
              value={dates}
            />
          ) }
          <Select
            onChange={(value) => {
              const newFilter = {
                ...filter,
                operator: value,
              };
              updateFilter('sdks', newFilter, { index })();
            }}
            size="small"
            style={{
              width: '80px',
            }}
            value={operator}
          >
            {['any', 'all'].map(x => (
              <Option key={`${index}sdk${x}`} value={x}>{capitalize(x)}</Option>
            ))}
          </Select>
        </div>
        <div className="following">
          of the following
        </div>
        <Select
          allowClear
          filterOption={false}
          labelInValue
          mode="multiple"
          notFoundContent={fetching ? <Spin size="small" /> : null}
          onChange={this.updateSdkFilter}
          onSearch={this.fetchSdkOptions}
          placeholder="Add SDKs or SDK categories"
          value={sdks}
        >
          {sdkOptions.map(x => (
            <Option key={`${x.name}${x.id}`} value={`${x.id} ${x.platform} ${x.type}`}>
              <div className="sdk-select-option">
                <i alt={x.platform} className={`fa fa-${x.platform === 'ios' ? 'apple' : 'android'}`} />
                {x.name}
                {' '}
                { x.type === 'sdkCategory' && <span style={{ fontSize: '12px' }}>(Category)</span> }
              </div>
            </Option>
          ))}
        </Select>
        {
          sdks.some(x => x.type === 'sdkCategory') &&
          <div className="sdk-categories">
            Specify category SDKs:
            <TreeSelect
              multiple
              onChange={(values) => {
                const newFilter = {
                  ...filter,
                  sdks: updateCategorySdks(sdks, values),
                };

                updateFilter('sdks', newFilter, { index })();
              }}
              showCheckedStrategy={TreeSelect.SHOW_PARENT}
              style={{ width: '100%' }}
              treeCheckable
              treeData={treeData}
              value={treeValues}
            />
          </div>
        }
      </div>
    );
  }
}

SdkFilterGroup.propTypes = {
  canDelete: PropTypes.bool.isRequired,
  deleteFilter: PropTypes.func.isRequired,
  duplicateSdkFilter: PropTypes.func.isRequired,
  filter: PropTypes.shape({
    eventType: PropTypes.string,
    dateRange: PropTypes.string,
    sdks: PropTypes.array,
    operator: PropTypes.string,
  }).isRequired,
  index: PropTypes.number.isRequired,
  platform: PropTypes.string.isRequired,
  updateFilter: PropTypes.func.isRequired,
};

export default SdkFilterGroup;