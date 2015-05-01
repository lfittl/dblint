# dblint [ ![Codeship Status for lfittl/dblint](https://img.shields.io/codeship/db703270-cfa3-0132-a2bb-623bdb9b8d89.svg)](https://codeship.com/projects/76752)

Automatically checks all SQL queries that are executed during your tests, to find common mistakes, including missing indices and locking issues due to long transactions.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dblint', group: :test
```

And then execute:

    $ bundle

## Usage

Run your tests as usual, for locking issues an exception will be raised if its severe enough:

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
