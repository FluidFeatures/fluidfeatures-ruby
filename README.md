[![Build Status](https://secure.travis-ci.org/FluidFeatures/fluidfeatures-ruby.png)](http://travis-ci.org/FluidFeatures/fluidfeatures-ruby)

Ruby graceful feature rollout and simple A/B testing
====================================================

`gem fluidfeatures-ruby` is a pure Ruby client for the API of FluidFeatures.com, which provides an elegant way to wrap new code so you have real-time control over rolling out new features to your user-base.

Integration with Rails
----------------------

If you are looking to use FluidFeatures with Rails then see https://github.com/FluidFeatures/fluidfeatures-rails

`gem fluidfeatures-rails` uses this `gem fluidfeatures-ruby` but integrates into Rails, which makes it quick and easy to use FluidFeatures with your Rails application.

Ruby specific usage (non-Rails usage)
=====================================

This gem can be used in any Ruby application. This means a Sinatra application, offline processing or sending emails. Anything that touches your user-base can have a customized experience for each user and can be a vehicle for A/B testing. For instance, you can test different email formats and see which one results in more conversions on your website. You could even integrate into a [Map-Reduce](http://www.bigfastblog.com/map-reduce-with-ruby-using-hadoop) job.

Installation
------------

```
gem install fluidfeatures-ruby
```

"Application"
-------------

You create a FluidFeatures::App (application) object with the credentials for accessing the FluidFeatures API. These credentials can be found of the application page of your FluidFeatures dashboard.

Call `app` on the `FluidFeatures` module to instantiate this object.

```ruby
require 'fluidfeatures'

config = {
  "base_uri" => "https://www.fluidfeatures.com/service"
  "app_id" => "1vu33ki6emqe3"
  "secret" = "sssseeecrrreeetttt"
}

fluid_app = FluidFeatures.app(config)
```

It's also possible to pass a logger object, which will direct all logging to your logger.

```ruby
fluid_app = FluidFeatures.app(config.update("logger" => logger))
```

User Transactions
-----------------

Each interaction with a user is wrapped in a transaction. In fluidfeature-rails, a transaction wraps a single HTTP request.

Transactions guarantee that the feature set for a user will be consistent during the transaction. It is possible that you might reconfigure which users see which features during a transaction, so this ensures that each request is processed atomically regardless of any changes that are occurring outside of the transaction.

To create a new user transaction call `user_transaction` on the `FluidFeatures::App` object, which we assigned to `fluid_app` above.

```ruby
fluid_user_transaction = fluid_app.user_transaction(user_id, url, display_name, is_anonymous, unique_attrs, cohort_attrs)
```

An transaction takes a few parameters.

`user_id` is the unique id that you generally refer to this user by. This can be a numeric or a string. If this is `nil` then the user is labeled anonymous and a unique id is generated to track this user. You can retrieve this unique id by using `anonymous_user_id = fluid_user_transaction.user.unique_id`. In HTTP context you should set a HTTP cookie with this `anonymous_user_id`, so that this user is consistently treated as the same user and experiences the same experience for each visit.

`url` is a reference to where the transaction is taking place. This has more meaning in HTTP context.

`display_name` is a human readable name of the user. eg. "Fred Flintstone". FluidFeatures will use this in the web dashboard for display purposes and also for searching for this user.

`is_anonymous` is a boolean that indicates whether this is an anonymous user or not. If this is true then `user_id` can be `nil` if you are not creating and tracking your own user ids for anonymous users.

`unique_attrs` is a `Hash` of other attributes that are unique to this user. For instance, their Twitter handle. Provide these are key-value pairs, which can be displayed and searched in the FluidFeatures dashboard. You can freely pass any key-value pairs you wish. For example, `:nickname => "The Hungry Bear"` or `:twitter => "@philwhln"`.

`cohort_attrs` is similar to `unique_attrs` but are not unique to this user. This is a way that you can group users together when managing feature visibility. These can be anything. A common one is `:admin => true` or `:admin => false`. Other ones include `:coffee_drinker => true`, `:age_group => "25-33"` or `:month_joined => "2012-july"`.

Within the FluidFeatures service, we plan to automatically add other cohorts, such as `:is_early_adopter`, `:active_user`, `:stale_user` to help you target your new features and engage the right users with the right features. This is outside the scope of this gem.

Is this feature enabled for this user?
--------------------------------------

This is at the core of graceful feature rollout. When the answer is always "no" for a feature, then you are able to push that feature into production without anyone knowing. After that you can start enabling it for specific users and groups of users.

To find out if the feature is enabled for the current user, call `feature_enabled?` on your `FluidFeatures::UserTransaction` object, which we assigned to `fluid_transaction` above.

```ruby
if fluid_user_transaction.feature_enabled? feature_name
  # implement feature here
end
```

In the above example it will use `"default"` for the version of the feature. If you wish to define your own version, you can pass `version_name` as shown below.

```ruby
if fluid_user_transaction.feature_enabled? feature_name, version_name
  # implement feature here
end
```

Real-world examples might be...

```ruby
if fluid_user_transaction.feature_enabled? "theme", "old-one"
  # show the user the old theme
end
if fluid_user_transaction.feature_enabled? "theme", "new-one"
  # show the user the new theme
end
```

```ruby
if fluid_user_transaction.feature_enabled? "email-sender", "postfix"
  # send email directly using postfix
end
if fluid_user_transaction.feature_enabled? "email-sender", "sendgrid-smtp"
  # send email using sendgrid's smtp interface
end
if fluid_user_transaction.feature_enabled? "email-sender", "sendgrid-api"
  # send email using sendgrid's http api
end
```

When FluidFeatures::UserTransaction gets a call to `feature_enabled?` it may not have seen this feature version before, so it will report this back to the FluidFeatures service as a new feature version. By default, new feature versions are disabled for all users until they are assigned to specific users, cohorts or percentage of users. This is not always ideal, since you may want to wrap an existing feature, such as the `["theme","old-one"]` above, in order to phase it out or test it against a newer version. It that case you can tell FluidFeatures explicitly what the default enabled state of this feature version should be, by passing `default_enabled` boolean as `true` or `false`. `true` will result is all users initially seeing this feature version.

```ruby
if fluid_user_transaction.feature_enabled? feature_name, version_name, default_enabled
  # implement feature here
end
```

It's a goal!
------------

The main motivation behind FluidFeatures is to make your site better, increase your conversion rate and ensure that the features you are developing are something that your customers want.

Rolling out new features is fun and doing it gracefully is important, but rolling out the right features is even more important. With "goals" you can keep track of how well each feature is doing and even run short A/B or multi-variant tests to validate your hypothesis about which version of a feature you should rollout.

As you start to rollout a newer version of a feature, you can watch how well your goals are performing for that version and for other versions. If early indications show that your newer version sucks and conversions are lagging, then you can rollback or pause rollout until you can understand the issue better.

Common high-level goals are "signed-up-to-mailing-list", "clicked-buy-button" or "visited-at-least-5-pages-during-session". Lower-level ones might include, "page-loaded-in-under-one-second", "no-errors-written-to-log" or "cpu-stayed-below-80-percent". Facebook tracks spikes in user comments, which they have found usually results in a feature gone wrong and users complaining. Your goals do not have to positive.

Goals are boolean and when one fires for a user then any feature enabled for that user at that time is held accountant, whether the goal is positive or negative.

Flagging a goal is easy. You simply call `goal_hit` on the `FluidFeatures::UserTransaction` object, which in the example below is `fluid_user_transaction`.

```ruby
fluid_user_transaction.goal_hit goal_name
```

Might look something like this...

```ruby
def buy_button_clicked
  @fluid_user_transaction.goal_hit "clicked-buy-button"
end
```

This goal will automatically appear in your FluidFeatures dashboard after the first time `goal_hit` is called with this value.

More info
=========

For more information visit http://www.fluidfeatures.com or email support@fluidfeatures.com

