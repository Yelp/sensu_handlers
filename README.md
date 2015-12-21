[![Build Status](https://travis-ci.org/Yelp/sensu_handlers.svg?branch=master)](https://travis-ci.org/Yelp/sensu_handlers)

# Yelp sensu\_handlers

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
* WARNING: The Jira project must *not* have special required fields
* WARNING: Jira has special "transition" states in order to close tickets,
this handler won't work if you have some custom "workflow"? (specifically, 
it won't be ble to close/fix/done issues. Patches welcome)
* WARNING: Be sure to use exponential backoff in order to not overload your
Jira server.

### Other

There are other handlers included here that are not yelp-specific in the sense
that they do not use the `team` construct, and are included out of convenience.

#### aws_prune

This is a modification of the `ec2_node` community handler. It caches the list
of ec2 instances from the Amazon API and will automatically remove servers
from Sensu if they do not exist in the API.

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

### Team Syntax

This is a very important aspect of the configuration of these sensu handlers.
The team syntax determines the default behavior of the handlers, given an input team.

*Warning*: If you typo a team name, the Sensu handlers will *not* know how to 
associate an alert with the right outputs. This is a common source of mistakes.

Lets look at the team synax in more detail:

```
sensu_handlers::teams:
  ops:
    pagerduty_api_key: 78923
    pages_irc_channel: 'ops-pages'
    notifications_irc_channel: 'operations-notifications'
    notification_email: 'operations@localhost'
    project: OPS
```

* *`sensu_handlers::teams:`* - Normal puppet-hiera lookup name. Matches 1:1 with the sensu_handlers module, teams parameter. This is a hash
* *`ops:`* - Team name. This is the primary lookup key
* *`pagerduty_api_key: deadbeef`* - In pagerduty, this corresponds to a "service". That service *must* use the "generic" or "sensu" api format. Sharing the api key with a "Nagios" service will *NOT* work
    pages_irc_channel: 'ops-pages'  # If there is an event with page=>true, a notification will go to this channel. This parameter defaults to $team-pages. It can take an array of channels. No need to have the leading "#".
* *`notifications_irc_channel: 'operations-notifications'`* - Non-paging events will appear here. If ommited, defaults to $team-notifications. This also can accept an array, and does not need a leading "#"
* *`notification_email: 'operations@localhost'`* - If set, the handler will send emails for every event to this address. If ommited it will send no emails. You can send the email to multiple destinations by using comma separated list (like any email client)
* *`project: OPS`* - Used by the JIRA handler. If a event comes in that has `ticket=>true`, the jira handler will open a ticket on this project. There no default for this parameter. Special considerations have to be made for the JIRA project to enable auto-opening and auto-closing of tickets, see the docs on the jira handler.


### Manually Invoking These Handlers

You can manually invoke these handlers in order to test them, ensuring that (for example) 
a JIRA ticket is correctly raised. Simply pipe the Sensu alert in JSON into one of the 
handlers, and it should parse it as if it were a fresh alert.

```
$ grep 'failed' /var/log/sensu/sensu-server.log  | tail -n 1 | jq .event > last_failed_event.json
$ cat last_failed_event | sudo -u sensu ruby jira.rb
```


### Support

Please open a github issue for support.
