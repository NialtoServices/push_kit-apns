# PushKit

PushKit makes it easy to create and deliver push notifications.

## PushKit::APNS

PushKit::APNS provides an easy-to-use API for creating and then delivering notifications via the Apple Push Notification service.
It uses the new HTTP/2 API and tokens so no more yearly certificate renewals!

## Installation

You can install **PushKit::APNS** using the following command:

    $ gem install push_kit-apns

### Usage

You'll need to grab a few things in order to send push notifications:

  - A key from the Apple Developer portal, one which has the push notification option enabled.
  - The ID of the key you're going to use.
  - The ID of the team that generated the key.
  - The bundle identifier of your application, which is used as the APNS topic.

Once you've obtained all of the above, you can create a new client like this:

```ruby
client = PushKit::APNS.client(
  key: PushKit::APNS.load_key('/path/to/APNsAuthKey_XXXXXXXXXX.p8'),
  key_id: 'XXXXXXXXXX',
  team_id: 'XXXXXXXXXX',
  topic: 'com.example.app'
)
```

Ideally, you should create the client when your app boots and keep it until your app is rebooted.
This allows us to maintain a connection to the Apple Push Notification service and quickly deliver notifications without the overhead of establishing a connection.

See [Communicating with APNs - Best Practices for Managing Connections](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html#//apple_ref/doc/uid/TP40008194-CH11-SW8) for more info on this.

### Additional Options

There are a few additional options you can specify when creating a client.

##### :host

You can provide the full hostname (or IP address) as a String. For example: 'api.push.apple.com'

Because this option's value is rarely set to anything other than the standard hostnames, we've added
a couple of convenience Symbols. These are *:development* and *:production* which sets the hostname
to the appropriate hostname for that environment.

The default value of this option is *:development*.

##### :port

You can also provide the port number as an Integer. For example: 443
This also has a couple of convenience Symbols, *:default* and *:alternative*.

The default value of this option is *:default*.

---

Creating a notification is easy with PushKit and there are quite a few different options you can set.
For a full list, checkout the documentation for `PushKit::APNS::Notification`.

For now, let's just create a simple notification:

```ruby
notification = PushKit::APNS::Notification.new
notification.title = 'Hello, World!'
notification.body = 'How are you today?'
notification.sound = :default
notification.device_token = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
```

Then using our `PushKit::APNS` instance we created earlier, deliver the notification:

```ruby
client.deliver(notification) do |notification, success, response|
  # ...
end
```

---

The `PushKit::APNS::Notification` instance has a *:device_token* attribute which needs to be set to the token of the device you're sending the notification to.

It's common to want to send the same notification to a bunch of devices. When you want to do this, leave the initial notification's *:device_token* attribute blank and instead use the helper method *:for_tokens*:

```ruby
notification = PushKit::APNS::Notification.new
notification.title = 'Hello, World!'
notification.body = 'How are you today?'
notification.sound = :default

tokens = %w[
  1111111111111111111111111111111111111111111111111111111111111111
  2222222222222222222222222222222222222222222222222222222222222222
  3333333333333333333333333333333333333333333333333333333333333333
]

notifications = notification.for_tokens(*tokens)
```

When you're ready, you can just deliver the array of notifications:

```ruby
client.deliver(*notifications) do |notification, success, response|
  # ...
end
```

## Development

After checking out the repo, run `bundle exec rake spec` to run the tests.

To install this gem onto your machine, run `bundle exec rake install`.
