# dblint [ ![](https://img.shields.io/gem/v/dblint.svg)](https://rubygems.org/gems/dblint) [ ![](https://img.shields.io/gem/dt/dblint.svg)](https://rubygems.org/gems/dblint) [ ![Codeship Status for lfittl/dblint](https://img.shields.io/codeship/db703270-cfa3-0132-a2bb-623bdb9b8d89.svg)](https://codeship.com/projects/76752)

Automatically checks all SQL queries that are executed during your tests, to find common mistakes, including missing indices and locking issues due to long transactions.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dblint', group: :test
```

And then execute:

    $ bundle

## Usage

Run your tests as usual, `dblint` will raise an exception or output a warning should it detect a problem.

Note that it will check the callstack for the problematic query, and only count it as an error if the callstack first line from within your app is not the `test` or `spec` directory. Therefore, should you use non-optimized code directly in your tests (e.g. as part of a factory), `dblint` will not raise an error.

## Missing indices

`dblint` will find SELECT queries that might be missing an index:

```
Failures:

  1) FeedsController#show 
     Failure/Error: get :show, format: :atom
     Dblint::Checks::MissingIndex::Error:
       Missing index on oauth_applications for '((twitter_app_name)::text = 'My Feed App'::text)' in 'SELECT  "oauth_applications".* FROM "oauth_applications" WHERE "oauth_applications"."twitter_app_name" = $1 LIMIT 1', called by app/controllers/feeds_controller.rb:6:in `show'
     # ./app/controllers/feeds_controller.rb:6:in `show'
     # ./spec/controllers/feeds_controller_spec.rb:12:in `block (3 levels) in <top (required)>'
     # ./spec/spec_helper.rb:78:in `block (2 levels) in <top (required)>'
```

This is done by `EXPLAIN`ing every SELECT statement run during your tests, and checking whether the execution plan contains a Sequential Scan that is filtered by a condition. Thus, if you were to do a count of all records, this check would not trigger.

Nonetheless, there might still be false positives or simply cases where you don't want an index - use the ignore list in those cases.

Note: `EXPLAIN` is run with `enable_seqscan = off` in order to avoid seeing a false positive Sequential Scan on indexed, but small tables (likely to happen with tests).

## Long held locks

`dblint` will find long held locks in database transactions, causing delays and possibly deadlocks:

```
  1) Invites::AcceptInvite test
     Failure/Error: described_class.call(user: invited_user)
     Dblint::LongHeldLock:
       Lock on ["users", 3] held for 29 statements (0.13 ms) by 'UPDATE "users" SET "invited_by_id" = $1, "role" = $2, "updated_at" = $3 WHERE "users"."id" = $4', transaction started by app/services/invites/accept_invite.rb:20:in `run'
     # ./app/services/invites/accept_invite.rb:20:in `run'
     # ./app/services/invites/accept_invite.rb:7:in `call'
     # ./spec/services/invites/accept_invite_spec.rb:8:in `accept_invite'
     # ./spec/services/invites/accept_invite_spec.rb:64:in `block (3 levels) in <top (required)>'
     # ./spec/spec_helper.rb:78:in `block (2 levels) in <top (required)>'
```

In this case it means that the `users` row has been locked for 29 statements (which took `0.13ms` in test, but this would be much more on any cloud setup), which can lead to lock contention issues on the `users` table, assuming other transactions are also updating that same row.

The correct fix for this depends on whether this is in user written code (i.e. a manual `ActiveRecord::Base.transaction` call), or caused by Rails built-ins like `touch: true` and `counter_cache: true`. In general you want to move that `UPDATE` to happen towards the end of the transaction, or move it completely outside (if you don't need the atomicity guarantee of the transaction).

Note: Right now the lock check can't detect possible problems caused by non-DB activities (e.g. updating your search index inside the transaction).

## Ignoring false positives

Since in some cases there might be a valid reason to not have an index, or to hold a lock for longer,
you can add ignores to the `.dblint.yml` file like this:

```
IgnoreList:
  MissingIndex:
    # Explain why you ignore it
    - app/models/my_model.rb:20:in `load'
  LongHeldLock:
    # Explain why you ignore it
    - app/models/my_model.rb:20:in `load'
```

The line you need to add is the first caller in the callstack from your main
application, also included in the error message for the check.

## Contributing

1. Fork it ( https://github.com/lfittl/dblint/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
