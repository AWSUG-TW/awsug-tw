AssetSync.configure do |config|
  config.fog_provider = 'AWS'
  config.fog_directory = 'cdn1.awsug.tw'
  config.aws_access_key_id = Setting.s3_access_key_id
  config.aws_secret_access_key = Setting.s3_secret_access_key
  config.fog_region = Setting.s3_fog_region
  config.fail_silently = true
end