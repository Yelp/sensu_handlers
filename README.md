[![Build Status](https://travis-ci.org/Yelp/sensu_handlers.svg?branch=master)](https://travis-ci.org/Yelp/sensu_handlers)

# Yelp sensu\_handlers

**Note:** These still have a load of Yelp specific code in them at the moment,
we're working on making these more generic!

**Warning:** These handlers are intended for use by Advanced sensu users.
Do not use them if you are setting up Sensu for the first time. Use 
standard handlers from the [community plugins repo](https://github.com/sensu/sensu-community-plugins/)

These work best with the Yelp `monitoring_check` or the `pysensu-yelp`
python library to make checks that these handlers act upon.

**To Repeat:** these handlers are special and require special event 
data to work. If the special event data (like `team`) is not provided,
these handlers will do nothing.

## Available Handlers

### Base

The base handler is the only handler necissary to use. It is the default.
All other handler behavior is derived from the event data. 

This allows checks to use one handler, and we can add new features or 
deprecate old ones without changing client-side configuration.

The base handler also handles advanced filtering. It respects the following
tunables:

* `alert_after` - Seconds to wait before any handler is activated. Defaults to
0.
* `realert_every` - Integer which filters out repeat events (uses "mod"). 
`realert_every => 2` would filter every other event. Defaults to `-1` which is
treated as a special input and does exponential backoff.

This handler also provides many helping functions to extract team data, etc.

All other handlers inherit the base handler.

### nodebot (irc)

Uses the [nodebot](https://github.com/thwarted/nodebot) tool to send IRC
notifications. Nodebot is helpful here as it retains a persistent connection
to the IRC server, which can be expensive to setup.

* Sends notification to the `pages_irc_channel` or `${team_name}-pages` if
the alert has `page => true`
* Sends notification IRC messages to the array of `irc_channels` specified by the
check, otherwise sends to the `notifications_irc_channel` specified in the team data.
* If out of all that there are no channels, then no notifications will be sent.

### mailer (notification emails)

Modification of the sensu-community-plugins mailer that can route emails to
different destinations depending on the circumstance.

* Sends an email to the `notification_email` destination if specified in the 
check.
* Otherwise it uses the `notification_email` specified by the team.
* Will refuse to send any email if `notification_email => false`.

### pagerduty (pages)

Modification of the sensu-community-plugins handler that can open events 
on different Pagerduty services depending on the inputs.

* Only activates if the `page` boolean key in the event data is set to true
* Uses the `pagerduty_api_key` config set to the `team` to determine which
service to open or close an event in.
* Tries to provide maximum context in the pagerduty event details
* Automatically closes events that are resolved.

### jira (tickets)

This handler can make a JIRA ticket for an alert. 

* The alert must have `ticket => true`
* Derives the Project to make the ticket in from the `project` key set in the
event data
* Falls back to the default project for the `team` if unset.

### Other

There are other handlers included here that are not yelp-specific in the sense
that they do not use the `team` construct, and are included out of convenience.

#### aws_prune

This is a modification of the `ec2_node` community handler. It caches the list
of ec2 instances from the Amazon API and will automatically remove servers
from Sensu if they do not exist in the API.

#### graphite

Standard handler, sends graphite metrics.

## Puppet Usage

If you are using the module itself, it can deploy the handlers and configure them.

```puppet
class sensu_handlers {
  # See the teams section
  $teams => $team_data,
}
```

## Puppet Parameters

See the inline docstrings in init.pp for parameter documentation.

## Teams

The Sensu handlers must have the team declarations available for consumption.
This data must be in hiera because currently the monitoring\_check module also
utilizes it.

On the plus side, hiera allows you to describe your team configuration easily:

```
sensu_handlers::teams:
  dev1:
    pagerduty_api_key: 1234
    pages_irc_channel: 'dev1-pages'
    notifications_irc_channel: 'dev1'
  dev2:
    pagerduty_api_key: 4567
    pages_irc_channel: 'dev2-pages'
    notifications_irc_channel: 'dev2'
  frontend:
    # The frontend team doesn't use pagerduty yet, just emails
    notifications_irc_channel: 'frontend'
    pages_irc_channel: 'frontend'
    notification_email: 'frontend+pages@localhost'
    project: WWW
  ops:
    pagerduty_api_key: 78923
    pages_irc_channel: 'ops-pages'
    notifications_irc_channel: 'operations-notifications'
    notification_email: 'operations@localhost'
    project: OPS
  hardware:
    # Uses the ops Pagerduty service for page-worhty events,
    # but otherwise just jira tickets
    pagerduty_api_key: 78923
    project: METAL
```


