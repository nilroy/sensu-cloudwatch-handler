#!/opt/sensu/embedded/bin/ruby
# Requires a Sensu configuration snippet:
#   {
#     "aws": {
#       "access_key": "adsafdafda",
#       "secret_key": "qwuieohajladsafhj23nm",
#       "region": "us-east-1c"
#     }
#   }
#
# Or you can set the following environment variables:
#   - AWS_ACCESS_KEY_ID
#   - AWS_SECRET_ACCESS_KEY
#   - EC2_REGION
# If neither is specified IAM roles are used
# Requires custom parameters defined in check definition
# => cloudwatch_dimensions -> array of hash
#    e.g [
#          {
#             "Name"  => "<dimension name>",
#             "Value" => "<dimension value>"
#
#          },...
#
#        ]
# => scheme -> The --scheme parameter used by plugin. e.g scheme -> :::environment:::.:::role:::.:::name:::
require 'rubygems'
require 'sensu-handler'
require 'fog'

class SensuToCloudWatch < Sensu::Handler
  def filter; end

  def handle
    AWS_ACCESS_KEY_ID = settings['aws']['AWS_ACCESS_KEY_ID'] || ENV['AWS_ACCESS_KEY_ID']
    AWS_SECRET_KEY = settings['aws']['AWS_SECRET_KEY'] || ENV['AWS_SECRET_KEY']
    region = settings['aws']['region'] || ENV['EC2_REGION']
    if AWS_ACCESS_KEY_ID and AWS_SECRET_KEY
      auth = {
        :aws_access_key_id => AWS_ACCESS_KEY_ID,
        :aws_secret_access_key  => AWS_SECRET_KEY,
        :region => region
      }
    else
      auth = {:use_iam_profile => true, :region => region }
    end
    cloudwatch = Fog::AWS::CloudWatch.new(auth)
    cloudwatch_dimensions = @event['check']['cloudwatch_dimensions']
    if cloudwatch_dimensions.nil?
      puts "Error: No cloudwatch metric dimension defined in the check #{@event['check']['name']}"
      exit 1
    end
    scheme = @event['check']['scheme']
    mydata = []
    @event['check']['output'].each_line do |metric|
      name, value, timestamp = metric.split(/\s+/)
      next unless name
      next unless value
      # Considering the --scheme in the sensu metric check as :::environment:::.:::role:::.:::name:::
      _name_ = name.split('.')
      scheme_length = scheme.split(".")
      if _name_.count > scheme_length
        environment = _name_[0]
        role = _name_[1]
        instance_name = @event['client']['name']
        metric = _name_[scheme_length..-1].join("_")
      else
        metric = name.gsub('.','_')
      end
      cloudwatch.put_metric_data("Sensu",[
        {
          "MetricName" => metric,
          "Value" => value,
          "Dimensions" => cloudwatch_dimensions
        }
        ])
    end
  end
end
