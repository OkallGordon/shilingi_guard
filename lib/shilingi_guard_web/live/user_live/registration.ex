defmodule ShilingiGuardWeb.UserLive.Registration do
  use ShilingiGuardWeb, :live_view

  alias ShilingiGuard.Accounts
  alias ShilingiGuard.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Create your Shilingi Guard account
            <:subtitle>
              Already registered?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                Log in
              </.link>
              to your account.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:full_name]}
            type="text"
            label="Full name"
            autocomplete="name"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
          />

          <.input
            field={@form[:phone_number]}
            type="tel"
            label="Phone number"
            autocomplete="tel"
            placeholder="e.g. 0712345678"
            required
          />

          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="new-password"
            required
          />

          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm password"
            autocomplete="new-password"
            required
          />

          <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
            Create an account
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: ShilingiGuardWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset =
      %User{}
      |> User.email_changeset(%{}, validate_unique: false)
      |> User.password_changeset(%{}, hash_password: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> User.email_changeset(user_params, validate_unique: false)
      |> User.password_changeset(user_params, hash_password: false)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
