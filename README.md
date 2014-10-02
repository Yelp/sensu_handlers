![Build status](https://travis-ci.org/Yelp/sensu_handlers.svg)

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

### nodebot (irc)

Uses the [nodebot](https://github.com/thwarted/nodebot) tool to send IRC
notifications. 

### mailer (notification emails)

Modification of the sensu-community-plugins mailer that responds to the 
notification_email key provided by the check definition.

### opsgenie (pages)

(No longer in use at Yelp). Uses a global API key and hand handle multiple
OpsGenie recipients on a per-team basis.

### pagerduty (pages)

Modification of the sensu-community-plugins handler that determins if an
alert should page or not based on the `page` boolean key in the event 
data. 

Additionally it directs the page to a different Pagerduty service depending
on the `team` variable.

### jira (tickets)

This handler can make a JIRA ticket for an alert. The alert must have `ticket`
set to `true`, and a `project` must be set for the team or for the check 
itself.

### Other

There are other handlers included here that are not yelp-specific in the sense
that they do not use the `team` construct, and are included out of convenience.

#### aws_prune

This is a modification of the `ec2_node` community handler. It caches the list
of ec2 instances from the Amazon API and will automatically remove servers
from Sensu if they do not exist in the API.

#### graphite

Standard handler, sends graphite metrics.

## Usage

TODO

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


