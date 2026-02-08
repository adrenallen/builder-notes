# handling workers with supervisor

Normally setup workers via supervisor.

I've run into issues with supervisor workers dying and FATAL out before they come back during maintenance windows. Add a startretries counter to let it try longer.

FWIW - Supervisor defaults to 3 quick retries, if db is down it will insta FATAL out and never come back until a manual start.

Example worker for /etc/supervisor/conf.d/laravel.conf:

```
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/laravel/artisan queue:work --queue=your-queue --sleep=3 --tries=3 --max-time=9600 --timeout=9600
autostart=true
autorestart=true
startretries=1000
stopasgroup=true
killasgroup=true
user=laravel
numprocs=6
redirect_stderr=true
stdout_logfile=/var/www/laravel/storage/logs/worker-unique-name.log
stopwaitsecs=300
```

# Long jobs
Don't use workers for long jobs! Put them into scheduled tasks that live in cron.
I tried doing long jobs for a while, see above example with huge max times and timeoutes. This sucks, because jobs require workers and then the queue system retries before a long job is done etc etc. Lots of bad things.

So instead you should use cron and install laravel scheduler into cron, like this (as a crontab)

```
* * * * * cd /var/www/laravel && php artisan schedule:run >> /var/www/laravel/storage/logs/cron.log 2>&1
```

Then in your console.php or w/e you put it like this:
```
Schedule::call(fn () => \App\Actions\SomeHugeProcess::run())
    ->name('a pretty name for my process')
    ->onOneServer()
    ->timezone('America/New_York')
    ->sundays()
    ->at('22:35');
```

Now you get cron outputs into the cron file.

The ONLY downside at the moment for this is that the logs will look weird in your alerting/reporting, because two tasks starting together will look like this in logs, TBD on a fix here... maybe per task logging files? idk yet

```
PROCESS A RUNNING
PROCESS B RUNNING

DONE [5m]
DONE [10m]
```

