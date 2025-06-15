defmodule LinkedinAiWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use LinkedinAiWeb, :controller` and
  `use LinkedinAiWeb, :live_view`.
  """
  use LinkedinAiWeb, :html

  embed_templates "layouts/*"
end
