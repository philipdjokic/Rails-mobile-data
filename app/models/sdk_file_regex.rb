class SdkFileRegex < ActiveRecord::Base

  belongs_to :android_sdk
  belongs_to :ios_sdk

  serialize :regex, Regexp
end
