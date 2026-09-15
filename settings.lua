data:extend({
	{
		type = "int-setting",
		name = "bbmi-max-rendered-module-icons",
		setting_type = "startup",
		minimum_value = 0,
		maximum_value = 20,
		default_value = 20,
		localised_name = { "mod-setting-name.bbmi-max-rendered-module-icons" },
		localised_description = { "mod-setting-description.bbmi-max-rendered-module-icons" }
	},
	{
		type = "double-setting",
		name = "bbmi-rendered-recipe-icon-scale",
		setting_type = "startup",
		minimum_value = 0.5,
		maximum_value = 3,
		default_value = 1.8,
		localised_name = { "mod-setting-name.bbmi-rendered-recipe-icon-scale" },
		localised_description = { "mod-setting-description.bbmi-rendered-recipe-icon-scale" }
	}
})
