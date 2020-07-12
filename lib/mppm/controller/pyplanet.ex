defmodule Mppm.Controller.Pyplanet do
  require Logger
  use GenServer
  alias Mppm.ServerConfig


  @pp_configs Application.get_env(:mppm, Mppm.Controller.Pyplanet)
  @servers_configs_root @pp_configs[:root_path]


  ###################################
  ##### START FUNCTIONS #############
  ###################################

  def get_command(%ServerConfig{login: name}),
    do: "#{@pp_configs[:root_path]}#{name}/manage.py start --pid-file #{name}.pid"



  ###################################
  ##### OTHER FUNCTIONS #############
  ###################################


  def create_config_file(%{config: server_config, listening_ports: %{"xmlrpc" => xmlport}}) do
    {:ok, base} = get_default_config_file("base")
    {:ok, apps} = get_default_config_file("apps")

    copy_default_folder(server_config)

    manage_filepath = @servers_configs_root <> server_config.login <> "/manage.py"
    updated_manage_content =
      File.read!(manage_filepath)
      |> String.replace("/default", "/#{server_config.login}")
    File.write(manage_filepath, updated_manage_content)

    create_db(server_config)

    base =
      base
      |> Kernel.put_in(["dedicated", "default", "PORT"], xmlport)
      |> Kernel.put_in(["dedicated", "default", "PASSWORD"], server_config.superadmin_pass)
      |> Kernel.put_in(["DATABASES", "default", "OPTIONS", "host"], @pp_configs[:db_host])
      |> Kernel.put_in(["DATABASES", "default", "OPTIONS", "user"], @pp_configs[:db_user])
      |> Kernel.put_in(["DATABASES", "default", "OPTIONS", "password"], @pp_configs[:db_pass])
      |> Kernel.put_in(["DATABASES", "default", "NAME"], "pp_" <> database_name(server_config))
      |> Kernel.put_in(["POOLS"], [server_config.login])
      |> Jason.encode!
      |> String.replace("default", server_config.login)

    apps =
      apps
      |> Jason.encode!
      |> String.replace("default", server_config.login)

    @servers_configs_root <> server_config.login <> "/settings/base.json"
    |> File.write(base)

    @servers_configs_root <> server_config.login <> "/settings/apps.json"
    |> File.write(apps)

    :ok
  end


  defp charlist(value) when is_binary(value), do: String.to_charlist(value)
  defp charlist(nil = _value), do: []


  def copy_default_folder(%Mppm.ServerConfig{login: name}) do
    File.cp_r(
      @servers_configs_root <> "default",
      @servers_configs_root <> name,
      fn _, _ -> true end
    )
  end

  def get_default_config_file(filename) when filename in ["apps", "base"] do
    @servers_configs_root <> "default/settings/#{filename}.json"
    |> File.read!
    |> Jason.decode
  end

  def create_db(%ServerConfig{} = server_config) do
    Mppm.Repo.query("CREATE DATABASE pp_#{database_name(server_config)} OWNER #{@pp_configs[:db_user]}")
  end


  def database_name(%ServerConfig{login: name}), do: String.downcase(name)





end
