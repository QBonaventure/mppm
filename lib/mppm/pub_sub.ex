defmodule Mppm.PubSub do


  def broadcast(topic, msg),
    do: Phoenix.PubSub.broadcast(__MODULE__, topic, msg)

  def subscribe(topic),
    do: Phoenix.PubSub.subscribe(__MODULE__, topic)

end
