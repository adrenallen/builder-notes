Everything in here is Laravel related

# Server Setup Quick Script
Checkout [cursed-server-setup.sh](./cursed-server-setup.sh) for a laravel + inertia + react + postgres quick setup script for ubuntu

# Delayed Jobs
## Dispatching jobs via artisan tinker

Requires calling Bus directly due to weirdness in how tinker handles dispatch facade

```php
Bus::dispatch(new Job())
```


## Laravel's retry_after and Long-Running Jobs: Avoiding Duplicate Processing

### NOTE - you should checkout the workers-and-long-jobs.md file and use that for long jobs, i.e. dont use jobs use scheduled tasks and cron!
Laravel's retry_after setting in config/queue.php (per connection) specifies how long a worker will wait before re-queueing a job that hasn't been completed or explicitly failed.

The Issue:

If retry_after is shorter than a job's actual processing time, the queue may re-queue the still-running job. This leads to multiple instances of the same job running concurrently, potentially causing "too many jobs" errors and resource exhaustion. For instance, a retry_after of 1 hour could cause a job taking slightly longer to be duplicated.

Solution: Dedicated Configuration for Long-Running Jobs

For jobs expected to run for extended periods:

Create a separate queue connection specifically for these long-running tasks.
Set a significantly higher retry_after value for this connection, appropriate for the maximum expected job duration, or configure it to minimize such retries.
Ensure the worker's timeout for this queue is also high, but critically, less than the retry_after value to prevent premature worker termination before a retry is legitimately considered.
This approach isolates long-running tasks, preventing unintended re-queues and ensuring stable job processing.


** IMPORTANT

in config/queue.php

retry_after  => If you hear nothing from the job (no success or failure) for x seconds, retry it.

in SomeJob.php

$retryAfter => If the job fails, retry it after x seconds.

# Environment setup
## Sail alias shortcut w/Docker
For new setups you might not have sail yet so here's a docker copy paster
```bash
docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "$(pwd):/var/www/html" \
    -w /var/www/html \
    laravelsail/php84-composer:latest \
    composer install --ignore-platform-reqs
```


# File Uploads
## Uploads not working with default storage facades

You need to link storage before it will work, sometimes this may not surface as an exception properly.

```bash
sail artisan storage:link
```

# Developer tools
## Pre-commit dev checks
See a pre-configured command `artisan dev:check` located under `artisan-dev-check` folder.

This command will run the expected default laravel github action tests for an inertia+react+laravel setup.

If you run into issues with a Feature/ExampleTest failure, you likely need to add a database refresh to the top of the test, like this

```php
<?php

uses(\Illuminate\Foundation\Testing\RefreshDatabase::class);

it('returns a successful response', function () {
    $response = $this->get('/');

    $response->assertStatus(200);
});
```

# User Registration/Creation
## Prevent disposable emails
Check the file located under `/laravel/disposable-emails` folder.

`NotDisposableEmail.php` is a Laravel Rule that will check the attached `disposable_email_blocklist.txt` for if the user is trying to register with a domain that is just a disposable email.

You can drop this into the Register endpoint (probabably under `RegisteredUserController`)

It should look something like this
```php
$request->validate([
    'name' => 'required|string|max:255',
    'email' => ['required', 'string', 'lowercase', 'email', 'max:255', 'unique:'.User::class, new NotDisposableEmail],
    'password' => ['required', 'confirmed', Rules\Password::defaults()],
]);
```

# 419 errors after setup
Are you using SQLite? Probably a db read error, or sqlite3 not installed on php extension. Most likely is permission error on the db though.

# 403 errors after setup
Are you using filament? Probably dont have the filamentuser implemented on the user model [SEE THIS](https://filamentphp.com/content/danharrin-panel-403-in-production)
