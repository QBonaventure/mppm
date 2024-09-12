# Game UI

The game UI is composed of various widgets who are all supervised by the GameUISupervisor.


## Building a manialink widget

Everything has to be written in Elixir and then get automatically converted to XML. Manialink element declaration simply is a simple tuple of three elements:

    {tag, list of attributes, list of content elements}

## Actions

Whenever an user interacts with an element of the UI with the ``action`` attribute, it triggers a ManiaPlanet.PlayerManialinkPageAnswer callback from the dedicated server. It is thus first treated by Mppm.Broker.MethodCall, which then calls a ``Mppm.GameUI.Actions.handle(method_call, server_login, user_login, params).

So for any action value set in your manialink element, you can expect to handle it in the Actions module, in the same pattern matching as we do for Broker.MethodCall and Broker.MethodResponse.

### Setting an action as an element attribute

In a pretty straightforward way, you can set your action in Manialink elements, in the form of ``action: "method:arg1:arg2:arg3``, arguments being optionnal (so ``action: "method"`` is valid).
