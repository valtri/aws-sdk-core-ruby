Next Release (TBD)
------------------

* Feature - Autoload - Service modules / classes now autoload upon first
  use. This speeds up gem load time significantly.

* Issue - SigV4 - Resolved an issue with how version 4 signatures generated
  the normalized querystring. Query params without a value now consistantly
  receive a trailing `=`.

2.0.0.rc16 (2014-09-11)
------------------

* Feature - Waiters - Added a new feature called waiters. Waiters poll a
  single API until a certain condition is matched. Waiters are invoked
  by a name and can be configured.

      # client waiter
      ec2 = Aws::EC2::Client.new
      ec2.wait_until(:instance_stopped, instance_ids:['i-12345678'])

      # resource waiters
      instance = Aws::EC2::Instance.new(id:'i-12345678')
      instance.start
      instance.wait_until_running

  See the client API documentation for `#wait_until` and the resource API
  documentation for `#wait_until_{condition}`.

* Feature - Resources - Merged in resources branch. You can now use 
  resource-oriented interfaces with `Aws::S3`, `Aws::EC2`, `Aws::SQS`,
  `Aws::SNS`, `Aws::Glacier`,
  and `Aws::IAM`.

* Feature - New Gems - Organized the repository into three gems, `aws-sdk`,
  `aws-sdk-resources`, and `aws-sdk-core`. Moved library and test files
  each into their respective gem directories.

* Issue - Error Class Names - Resolved an issue that could raise a
  `NameError`, "wrong constant name" at runtime in response to a service
  error. Fixes #97.

* Issue - `Aws::CloudSearchDomain::Client` - Resolved an issue that would cause
  the `Aws::CloudSearchDomain::Client` constructor to raise an error when
  `Aws.config[:region]` is set. Fixes #103.

* Issue - Shared Credentials - Resolved an issue where an error was raised
  if the shared AWS credentials file is present and is empty or missing the
  default profile. Fixes #104.

2.0.0.rc15 (2014-08-14)
-----------------------

* Feature - `Aws::S3::Client` - Enabling url-encoding of Amazon S3 keys by default.
  Keys are decoded before response data is returned. See [#95](https://github.com/aws/aws-sdk-core-ruby/issues/95).

* Feature - `Aws::ElasticLoadBalancing::Client` - Added support for the new tagging
  operations.

* Feature - `Aws::CloudSearch::Client` - Will now sign requests when credentials
  are provided. You can continue making unauthenticated requests if you do not
  configure credentials to the client.

* Feature - Coverage - Now generating coverage reports during Travis builds
  and reporting via Coveralls.io.

* Upgrading - `Aws::DynamoDB::Client` - Added a plugin that simplifies working
  with DynamoDB attribute values. Enabled by default, to restore default
  behavior, use `:simple_attributes => false`.

* Issue - Documentation - Now loading API files with UTF-8 encoding.
  See [#92](https://github.com/aws/aws-sdk-core-ruby/issues/92).

2.0.0.rc14 (2014-08-05)
-----------------------

* Upgrading - Client Classes - Versioned client classes removed, e.g.
  `Aws::S3::Client::V20060301.new` is now `Aws::S3::Client.new` The
  `:api_version` constructor option is no longer accepted.

* Upgrading - `Aws` Module - Helper methods on `Aws` for client classes
  deprecated; For example, calling `Aws.s3` will generate a deprecation
  warning. Use `Aws::S3::Client.new` instead. Helpers will be removed as
  of v2.0.0 final.

* Upgrading - Config - When configuring an `:endpoint`, you must now specify
  the HTTP scheme, e.g. "http://localhost:3000", instead of "localhost:3000".

2.0.0.rc1 - 2.0.0.rc13
----------------------

* No changelog entries.
