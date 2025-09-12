defmodule LinkedinAiWeb.ContentLive do
  @moduledoc """
  Content generation LiveView for creating AI-powered LinkedIn content.
  """

  use LinkedinAiWeb, :live_view

  alias LinkedinAi.ContentGeneration
  alias LinkedinAi.AI
  alias LinkedinAi.Subscriptions
  alias LinkedinAi.Billing
  alias LinkedinAi.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:page_title, "Content Generation")
      |> assign(:current_step, 1)
      |> assign(:form, to_form(%{}))
      |> assign(:generated_content, nil)
      |> assign(:generating, false)
      |> assign(:templates, AI.get_content_templates("post"))
      |> assign(:user_contents, [])
      |> assign(:selected_template, nil)

    if connected?(socket) do
      user_contents = ContentGeneration.list_user_contents(user, [])
      socket = assign(socket, :user_contents, user_contents)
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("select_template", %{"template" => template_name}, socket) do
    template = Enum.find(socket.assigns.templates, &(&1.name == template_name))

    socket =
      socket
      |> assign(:selected_template, template)
      |> assign(:current_step, 2)

    {:noreply, socket}
  end

  @impl true
  def handle_event("back_to_templates", _params, socket) do
    socket =
      socket
      |> assign(:selected_template, nil)
      |> assign(:current_step, 1)
      |> assign(:form, to_form(%{}))

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_form", %{"content" => params}, socket) do
    # Simple validation - in a real app you'd use a changeset
    form = to_form(params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("generate_content", %{"content" => params}, socket) do
    user = socket.assigns.current_user

    # Check usage limits
    if Subscriptions.usage_limit_exceeded?(user, "content_generation") do
      socket =
        put_flash(
          socket,
          :error,
          "You've reached your monthly content generation limit. Please upgrade your plan."
        )

      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:generating, true)
        |> assign(:generated_content, nil)

      # Generate content asynchronously
      send(self(), {:generate_content, params})

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("regenerate", _params, socket) do
    if socket.assigns.form.params do
      socket = assign(socket, :generating, true)
      send(self(), {:generate_content, socket.assigns.form.params})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_content", _params, socket) do
    case socket.assigns.generated_content do
      nil ->
        {:noreply, put_flash(socket, :error, "No content to save")}

      content ->
        user = socket.assigns.current_user

        content_attrs = %{
          user_id: user.id,
          content_type: content.content_type,
          prompt: content.prompt,
          generated_text: content.text,
          tone: content.tone,
          target_audience: content.target_audience,
          word_count: String.split(content.text) |> length(),
          generation_model: content.model,
          generation_tokens_used: content.tokens_used,
          generation_cost: content.cost
        }

        case ContentGeneration.create_generated_content(content_attrs) do
          {:ok, _saved_content} ->
            # Refresh user contents list
            user_contents = ContentGeneration.list_user_contents(user, [])

            socket =
              socket
              |> assign(:user_contents, user_contents)
              |> put_flash(:info, "Content saved successfully!")

            {:noreply, socket}

          {:error, _changeset} ->
            socket = put_flash(socket, :error, "Failed to save content")
            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("toggle_favorite", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case ContentGeneration.get_user_content(user, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Content not found")}

      content ->
        case ContentGeneration.toggle_favorite(content) do
          {:ok, _updated_content} ->
            user_contents = ContentGeneration.list_user_contents(user, [])
            socket = assign(socket, :user_contents, user_contents)
            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update favorite status")}
        end
    end
  end

  @impl true
  def handle_event("delete_content", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case ContentGeneration.get_user_content(user, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Content not found")}

      content ->
        case ContentGeneration.delete_generated_content(content) do
          {:ok, _deleted_content} ->
            user_contents = ContentGeneration.list_user_contents(user, [])

            socket =
              socket
              |> assign(:user_contents, user_contents)
              |> put_flash(:info, "Content deleted successfully")

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to delete content")}
        end
    end
  end

  @impl true
  def handle_info({:generate_content, params}, socket) do
    user = socket.assigns.current_user

    # Prepare generation parameters
    generation_params = %{
      prompt: params["prompt"] || "",
      content_type: params["content_type"] || "post",
      tone: params["tone"] || "professional",
      target_audience: params["target_audience"] || "general"
    }

    case ContentGeneration.generate_content(user, generation_params) do
      {:ok, generated_content} ->
        socket =
          socket
          |> assign(:generating, false)
          |> assign(:generated_content, generated_content)
          |> assign(:current_step, 3)

        {:noreply, socket}

      {:error, :usage_limit_exceeded} ->
        socket =
          socket
          |> assign(:generating, false)
          |> put_flash(:error, "You've reached your monthly content generation limit")

        {:noreply, socket}

      {:error, _reason} ->
        socket =
          socket
          |> assign(:generating, false)
          |> put_flash(:error, "Failed to generate content. Please try again.")

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto">
      <!-- Header -->
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Content Generation</h1>
        <p class="mt-2 text-gray-600">
          Create engaging LinkedIn content with AI assistance
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Main Content Area -->
        <div class="lg:col-span-2">
          <!-- Step Indicator -->
          <div class="mb-8">
            <nav aria-label="Progress">
              <ol role="list" class="flex items-center">
                <.step_indicator step={1} current_step={@current_step} title="Choose Template" />
                <.step_indicator step={2} current_step={@current_step} title="Customize Content" />
                <.step_indicator step={3} current_step={@current_step} title="Review & Save" />
              </ol>
            </nav>
          </div>
          
    <!-- Step Content -->
          <%= case @current_step do %>
            <% 1 -> %>
              <.template_selection templates={@templates} />
            <% 2 -> %>
              <.content_form form={@form} template={@selected_template} generating={@generating} />
            <% 3 -> %>
              <.content_preview content={@generated_content} form={@form} generating={@generating} />
          <% end %>
        </div>
        
    <!-- Sidebar -->
        <div class="space-y-6">
          <!-- Usage Stats -->
          <.usage_stats_card current_user={@current_user} />
          
    <!-- Recent Content -->
          <.recent_content_card user_contents={@user_contents} />
        </div>
      </div>
    </div>
    """
  end

  # Component: Step Indicator
  defp step_indicator(assigns) do
    is_current = assigns.step == assigns.current_step
    is_completed = assigns.step < assigns.current_step
    assigns = assign(assigns, :is_current, is_current)
    assigns = assign(assigns, :is_completed, is_completed)

    ~H"""
    <li class={["relative", if(@step < 3, do: "pr-8 sm:pr-20", else: "")]}>
      <%= if @step < 3 do %>
        <!-- Arrow separator for steps in between start and end -->
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="h-0.5 w-full bg-gray-200"></div>
        </div>
      <% end %>

      <div class="relative flex h-8 w-8 items-center justify-center rounded-full">
        <%= cond do %>
          <% @is_completed -> %>
            <div class="h-8 w-8 rounded-full bg-blue-600 flex items-center justify-center">
              <.icon name="hero-check" class="h-5 w-5 text-white" />
            </div>
          <% @is_current -> %>
            <div class="h-8 w-8 rounded-full border-2 border-blue-600 bg-white flex items-center justify-center">
              <span class="h-2.5 w-2.5 rounded-full bg-blue-600"></span>
            </div>
          <% true -> %>
            <div class="h-8 w-8 rounded-full border-2 border-gray-300 bg-white flex items-center justify-center">
              <span class="h-2.5 w-2.5 rounded-full bg-transparent"></span>
            </div>
        <% end %>
      </div>

      <span class="absolute top-10 left-1/2 transform -translate-x-1/2 text-xs font-medium text-gray-500">
        {@title}
      </span>
    </li>
    """
  end

  # Component: Template Selection
  defp template_selection(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <h2 class="text-lg font-medium text-gray-900 mb-6">Choose a Content Template</h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <%= for template <- @templates do %>
          <div
            phx-click="select_template"
            phx-value-template={template.name}
            class="relative rounded-lg border border-gray-300 bg-white px-6 py-5 shadow-sm flex items-center space-x-3 hover:border-gray-400 focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-blue-500 cursor-pointer transition-colors duration-200"
          >
            <div class="flex-shrink-0">
              <div class="h-10 w-10 rounded-lg bg-blue-100 flex items-center justify-center">
                <.icon name="hero-document-text" class="h-6 w-6 text-blue-600" />
              </div>
            </div>
            <div class="flex-1 min-w-0">
              <span class="absolute inset-0" aria-hidden="true"></span>
              <p class="text-sm font-medium text-gray-900">{template.name}</p>
              <p class="text-sm text-gray-500 truncate">{template.description}</p>
            </div>
            <div class="flex-shrink-0">
              <.icon name="hero-chevron-right" class="h-5 w-5 text-gray-400" />
            </div>
          </div>
        <% end %>
      </div>
      
    <!-- Custom Template Option -->
      <div class="mt-6 pt-6 border-t border-gray-200">
        <div
          phx-click="select_template"
          phx-value-template="custom"
          class="relative rounded-lg border-2 border-dashed border-gray-300 bg-white px-6 py-5 flex items-center space-x-3 hover:border-gray-400 cursor-pointer transition-colors duration-200"
        >
          <div class="flex-shrink-0">
            <div class="h-10 w-10 rounded-lg bg-gray-100 flex items-center justify-center">
              <.icon name="hero-plus" class="h-6 w-6 text-gray-600" />
            </div>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-gray-900">Create Custom Content</p>
            <p class="text-sm text-gray-500">Start from scratch with your own prompt</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Component: Content Form
  defp content_form(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-lg font-medium text-gray-900">Customize Your Content</h2>
        <button phx-click="back_to_templates" class="text-sm text-gray-500 hover:text-gray-700">
          ← Back to templates
        </button>
      </div>

      <.form for={@form} phx-change="validate_form" phx-submit="generate_content" class="space-y-6">
        <!-- Content Type -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Content Type</label>
          <select
            name="content[content_type]"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          >
            <option value="post">LinkedIn Post</option>
            <option value="comment">Comment</option>
            <option value="message">Direct Message</option>
            <option value="article">Article</option>
          </select>
        </div>
        
    <!-- Prompt -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Content Prompt <span class="text-red-500">*</span>
          </label>
          <%= if @template && @template.name != "custom" do %>
            <p class="text-sm text-gray-500 mb-2">Template: {@template.description}</p>
            <textarea
              name="content[prompt]"
              rows="4"
              placeholder={@template.template_prompt}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              required
            >{@form[:prompt].value}</textarea>
          <% else %>
            <textarea
              name="content[prompt]"
              rows="4"
              placeholder="Describe what you want to write about..."
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              required
            >{@form[:prompt].value}</textarea>
          <% end %>
        </div>
        
    <!-- Tone -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Tone</label>
          <select
            name="content[tone]"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          >
            <option value="professional">Professional</option>
            <option value="casual">Casual</option>
            <option value="enthusiastic">Enthusiastic</option>
            <option value="informative">Informative</option>
            <option value="friendly">Friendly</option>
          </select>
        </div>
        
    <!-- Target Audience -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Target Audience</label>
          <select
            name="content[target_audience]"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          >
            <option value="general">General Audience</option>
            <option value="executives">Executives</option>
            <option value="peers">Industry Peers</option>
            <option value="industry">Industry Professionals</option>
            <option value="students">Students</option>
          </select>
        </div>
        
    <!-- Generate Button -->
        <div class="flex justify-end">
          <button
            type="submit"
            disabled={@generating}
            class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <%= if @generating do %>
              <.icon name="hero-arrow-path" class="animate-spin -ml-1 mr-3 h-5 w-5" /> Generating...
            <% else %>
              <.icon name="hero-sparkles" class="-ml-1 mr-3 h-5 w-5" /> Generate Content
            <% end %>
          </button>
        </div>
      </.form>
    </div>
    """
  end

  # Component: Content Preview
  defp content_preview(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @generating do %>
        <div class="bg-white shadow rounded-lg p-6">
          <div class="text-center py-12">
            <div class="inline-flex items-center px-4 py-2 font-semibold leading-6 text-sm shadow rounded-md text-blue-500 bg-blue-100">
              <.icon name="hero-arrow-path" class="animate-spin -ml-1 mr-3 h-5 w-5" />
              Generating your content...
            </div>
            <p class="mt-2 text-sm text-gray-500">This may take a few seconds</p>
          </div>
        </div>
      <% else %>
        <%= if @content do %>
          <!-- Generated Content -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-medium text-gray-900">Generated Content</h2>
              <div class="flex space-x-2">
                <button
                  phx-click="regenerate"
                  class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  <.icon name="hero-arrow-path" class="h-4 w-4 mr-2" /> Regenerate
                </button>
                <button
                  phx-click="save_content"
                  class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  <.icon name="hero-bookmark" class="h-4 w-4 mr-2" /> Save
                </button>
              </div>
            </div>
            
    <!-- Content Display -->
            <div class="bg-gray-50 rounded-lg p-4 mb-4">
              <div class="whitespace-pre-wrap text-gray-900">{@content.text}</div>
            </div>
            
    <!-- Content Stats -->
            <div class="grid grid-cols-3 gap-4 text-sm">
              <div>
                <span class="text-gray-500">Words:</span>
                <span class="font-medium ml-1">{String.split(@content.text) |> length()}</span>
              </div>
              <div>
                <span class="text-gray-500">Tokens:</span>
                <span class="font-medium ml-1">{@content.tokens_used}</span>
              </div>
              <div>
                <span class="text-gray-500">Cost:</span>
                <span class="font-medium ml-1">${@content.cost}</span>
              </div>
            </div>
          </div>
          
    <!-- Actions -->
          <div class="bg-white shadow rounded-lg p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">What's Next?</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <button
                phx-click="back_to_templates"
                class="inline-flex items-center justify-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Create Another
              </button>
              <.link
                href="/content"
                class="inline-flex items-center justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                View All Content
              </.link>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # Component: Usage Stats Card
  defp usage_stats_card(assigns) do
    current_usage = Subscriptions.get_current_usage(assigns.current_user, "content_generation")
    limit = get_content_limit(assigns.current_user)
    percentage = if limit > 0, do: min(100, current_usage / limit * 100), else: 0

    assigns = assign(assigns, :current_usage, current_usage)
    assigns = assign(assigns, :limit, limit)
    assigns = assign(assigns, :percentage, percentage)

    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Monthly Usage</h3>

      <div class="space-y-4">
        <div>
          <div class="flex justify-between text-sm mb-2">
            <span class="text-gray-700">Content Generation</span>
            <span class="text-gray-500">
              {@current_usage}
              <%= if @limit > 0 do %>
                /{@limit}
              <% else %>
                /∞
              <% end %>
            </span>
          </div>
          <div class="bg-gray-200 rounded-full h-2">
            <div
              class={[
                "h-2 rounded-full transition-all duration-300",
                if(@percentage >= 90,
                  do: "bg-red-500",
                  else: if(@percentage >= 70, do: "bg-yellow-500", else: "bg-green-500")
                )
              ]}
              style={"width: #{@percentage}%"}
            >
            </div>
          </div>
        </div>

        <%= if @percentage >= 90 do %>
          <div class="bg-red-50 border border-red-200 rounded-md p-3">
            <div class="flex">
              <div class="flex-shrink-0">
                <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-red-400" />
              </div>
              <div class="ml-3">
                <p class="text-sm text-red-700">
                  You're approaching your monthly limit.
                  <.link href="/subscription" class="font-medium underline">
                    Upgrade your plan
                  </.link>
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Component: Recent Content Card
  defp recent_content_card(assigns) do
    recent_contents = Enum.take(assigns.user_contents, 5)
    assigns = assign(assigns, :recent_contents, recent_contents)

    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Recent Content</h3>
        <.link href="/content" class="text-sm text-blue-600 hover:text-blue-500">
          View all →
        </.link>
      </div>

      <%= if Enum.empty?(@recent_contents) do %>
        <div class="text-center py-6">
          <.icon name="hero-document-text" class="mx-auto h-12 w-12 text-gray-400" />
          <h3 class="mt-2 text-sm font-medium text-gray-900">No content yet</h3>
          <p class="mt-1 text-sm text-gray-500">
            Get started by creating your first piece of content.
          </p>
        </div>
      <% else %>
        <div class="space-y-3">
          <%= for content <- @recent_contents do %>
            <div class="flex items-center space-x-3 p-3 bg-gray-50 rounded-lg">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                  <.icon name="hero-document-text" class="h-4 w-4 text-blue-600" />
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-gray-900 truncate">
                  {String.slice(content.generated_text, 0, 50)}...
                </p>
                <p class="text-xs text-gray-500">
                  {Timex.from_now(content.inserted_at)}
                </p>
              </div>
              <div class="flex-shrink-0 flex space-x-1">
                <button
                  phx-click="toggle_favorite"
                  phx-value-id={content.id}
                  class={[
                    "p-1 rounded-full hover:bg-gray-200",
                    if(content.is_favorite, do: "text-yellow-500", else: "text-gray-400")
                  ]}
                >
                  <.icon name="hero-star" class="h-4 w-4" />
                </button>
                <button
                  phx-click="delete_content"
                  phx-value-id={content.id}
                  data-confirm="Are you sure you want to delete this content?"
                  class="p-1 rounded-full hover:bg-gray-200 text-gray-400 hover:text-red-500"
                >
                  <.icon name="hero-trash" class="h-4 w-4" />
                </button>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper function
  defp get_content_limit(user) do
    case Billing.get_current_subscription(user) do
      %{plan_type: "basic"} -> 10
      # unlimited
      %{plan_type: "pro"} -> -1
      _ -> if User.in_trial?(user), do: 3, else: 0
    end
  end
end
