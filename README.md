# sensu\_handlers

## Usage

### Teams

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


