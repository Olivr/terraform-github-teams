# ---------------------------------------------------------------------------------------------------------------------
# Computations
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # Set defaults
  default_team = {
    description = ""
    privacy     = "closed"
    members     = {}
  }

  # Teams that should be created
  parents = { for team_id, config in var.teams :
    team_id => defaults(config, local.default_team) if config != null
  }

  children = merge(flatten([for parent_team, parent_config in local.parents :
    { for team, config in parent_config.teams :
      team => merge(defaults(config, local.default_team), { parent = parent_team }) if config != null
    } if lookup(parent_config, "teams", {}) != {}
  ])...)

  grand_children = merge(flatten([for parent_team, parent_config in local.children :
    { for team, config in parent_config.teams :
      team => merge(defaults(config, local.default_team), { parent = parent_team }) if config != null
    } if lookup(parent_config, "teams", {}) != {}
  ])...)

  teams_created = merge(github_team.parents, github_team.children, github_team.grandchildren)

  # Users to be added to teams
  memberships = merge(flatten([for team_id, config in merge(local.parents, local.children, local.grand_children) :
    { for member in config.members :
      "${team_id}-${member.role}-${member.user}" => merge(member, { team_id = local.teams_created[team_id].id }) if lookup(local.teams_created, "team_id", null) != null
    } if lookup(config, "members", {}) != {} && lookup(config, "members", null) != null
  ])...)
}

# ---------------------------------------------------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------------------------------------------------
# Create parent teams
resource "github_team" "parents" {
  for_each = var.enable ? local.parents : {}

  name        = each.value.name
  description = each.value.description
  privacy     = each.value.privacy
}

# Create children teams
resource "github_team" "children" {
  for_each = var.enable ? local.children : {}

  name           = each.value.name
  description    = each.value.description
  privacy        = each.value.privacy
  parent_team_id = github_team.parents[each.value.parent].id
}

# Create grand children teams
resource "github_team" "grandchildren" {
  for_each = var.enable ? local.grand_children : {}

  name           = each.value.name
  description    = each.value.description
  privacy        = each.value.privacy
  parent_team_id = github_team.children[each.value.parent].id
}

# Add users to teams
resource "github_team_membership" "members" {
  for_each = var.enable ? local.memberships : {}

  team_id  = each.value.team_id
  username = each.value.user
  role     = each.value.role
}
