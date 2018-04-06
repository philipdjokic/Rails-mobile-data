/* eslint-env jest */

import { generateSdkFilter } from '../../../explore/sdkFilterBuilder.utils';

describe('buildSdkFilters', () => {
  it('should create a filter for an sdk category currently installed', () => {
    const filter = {
      sdks: [{
        id: 114,
        name: 'Analytics',
        type: 'sdkCategory',
        platform: 'ios',
        sdks: [
          { id: 12, name: 'bob' },
          { id: 56, name: 'joe' },
          { id: 234, name: 'dan' },
          { id: 734, name: 'sue' },
          { id: 34, name: 'dave' },
          { id: 5, name: 'jan' },
        ],
        includedSdks: [
          { id: 12, name: 'bob' },
          { id: 56, name: 'joe' },
          { id: 234, name: 'dan' },
          { id: 734, name: 'sue' },
          { id: 34, name: 'sue' },
          { id: 5, name: 'sue' },
        ],
      }],
      eventType: 'install',
      dateRange: 'anytime',
      dates: [],
      operator: 'any',
      installState: 'is-installed',
    };

    const expected = {
      operator: 'union',
      inputs: [
        {
          operator: 'intersect',
          inputs: [
            {
              object: 'sdk_event',
              operator: 'filter',
              predicates: [
                ['type', 'install'],
                ['sdk_category', 'Analytics', 'ios'],
              ],
            },
            {
              object: 'app',
              operator: 'filter',
              predicates: [
                ['platform', 'ios'],
              ],
            },
            {
              object: 'sdk_event',
              operator: 'filter',
              predicates: [
                ['installed'],
                ['sdk_category', 'Analytics', 'ios'],
              ],
            },
          ],
        },
      ],
    };

    const sdkFilter = generateSdkFilter(filter);

    expect(sdkFilter).toEqual(expected);
  });
});

describe('buildSdkFilters', () => {
  it('should create a filter for an sdk category currently installed with excluded SDKs', () => {
    const filter = {
      sdks: [{
        id: 114,
        name: 'Analytics',
        type: 'sdkCategory',
        platform: 'ios',
        sdks: [
          { id: 12, name: 'bob' },
          { id: 56, name: 'joe' },
          { id: 234, name: 'dan' },
          { id: 734, name: 'sue' },
          { id: 34, name: 'dave' },
          { id: 5, name: 'jan' },
        ],
        includedSdks: [
          { id: 12, name: 'bob' },
          { id: 56, name: 'joe' },
          { id: 234, name: 'dan' },
          { id: 734, name: 'sue' },
        ],
      }],
      eventType: 'install',
      dateRange: 'anytime',
      dates: [],
      operator: 'any',
      installState: 'is-installed',
    };

    const expected = {
      operator: 'union',
      inputs: [
        {
          operator: 'intersect',
          inputs: [
            {
              object: 'sdk_event',
              operator: 'filter',
              predicates: [
                ['type', 'install'],
                ['sdk_category', 'Analytics', 'ios', [34, 5]],
              ],
            },
            {
              object: 'app',
              operator: 'filter',
              predicates: [
                ['platform', 'ios'],
              ],
            },
            {
              object: 'sdk_event',
              operator: 'filter',
              predicates: [
                ['installed'],
                ['sdk_category', 'Analytics', 'ios', [34, 5]],
              ],
            },
          ],
        },
      ],
    };

    const sdkFilter = generateSdkFilter(filter);

    expect(sdkFilter).toEqual(expected);
  });
});
