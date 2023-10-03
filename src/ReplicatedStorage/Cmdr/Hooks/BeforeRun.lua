return function(registry)
	registry:RegisterHook("BeforeRun", function(context)
		if context.Executor:GetAttribute("Cmdr_Admin") ~= true then
			return "You don't have permission to run this command" :: string?
		end
		return nil
	end)
end
