Spawner = class()
Spawner.poseWeightCount = 1
Spawner.connectionInput = sm.interactable.connectionType.logic
Spawner.maxParentCount = 1
Spawner.maxChildCount = 0

function Spawner.onCreate( self )
	self.interactable.publicData = {}
end

function Spawner.server_onFixedUpdate( self )
	local Enabled = false
	for key,obj in pairs(self.interactable:getParents()) do
		if obj.active then
			Enabled = true
			break
		end
	end
	if self.interactable.publicData then
		self.interactable.publicData.enabled = Enabled
	end
end