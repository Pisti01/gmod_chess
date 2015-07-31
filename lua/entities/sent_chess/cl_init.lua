include('shared.lua')

local brdpos = {
	["x"] = {
		[1] = -14.7,
		[2] = -10.5,
		[3] = -6.3,
		[4] = -2.1,
		[5] = 2.1,
		[6] = 6.3,
		[7] = 10.5,
		[8] = 14.7
	},
	["y"] = {
		[1] = -14.45,
		[2] = -10.3,
		[3] = -6.15,
		[4] = -2,
		[5] = 2.25,
		[6] = 6.4,
		[7] = 10.55,
		[8] = 14.7
	}
}
local rectpos = {
	["x"] = {
		[1] = -4 * 5,
		[2] = -3 * 5,
		[3] = -2 * 5,
		[4] = -1 * 5,
		[5] = 0 * 5,
		[6] = 1 * 5,
		[7] = 2 * 5,
		[8] = 3 * 5
	},
	["y"] = {
		[1] = 3 * 5,
		[2] = 2 * 5,
		[3] = 1 * 5,
		[4] = 0 * 5,
		[5] = -1 * 5,
		[6] = -2 * 5,
		[7] = -3 * 5,
		[8] = -4 * 5
	}
}
local ChessModels = {
		[1] = "models/props_phx/games/chess/white_rook.mdl",
		[2] = "models/props_phx/games/chess/white_knight.mdl",
		[3] = "models/props_phx/games/chess/white_bishop.mdl",
		[4] = "models/props_phx/games/chess/white_king.mdl",
		[5] = "models/props_phx/games/chess/white_queen.mdl",
		[6] = "models/props_phx/games/chess/white_pawn.mdl",
		[7] = "models/props_phx/games/chess/black_rook.mdl",
		[8] = "models/props_phx/games/chess/black_knight.mdl",
		[9] = "models/props_phx/games/chess/black_bishop.mdl",
		[10] = "models/props_phx/games/chess/black_king.mdl",
		[11] = "models/props_phx/games/chess/black_queen.mdl",
		[12] = "models/props_phx/games/chess/black_pawn.mdl"
	}

surface.CreateFont( "ChessGameFontPlayer", {
	font 		= "Default",
	size 		= 30,
	weight 		= 450,
	antialias 	= true,
	additive 	= false,
	shadow 		= false,
	outline 	= false
} )

net.Receive('Chess_SendPlyData', function()
	local chess = Entity(net.ReadUInt(32))
	if not IsValid(chess) then return end
	chess.piece.type = net.ReadTable()
	chess.piece.moved = net.ReadTable()
	chess.sel = { ["x"] = 0, ["y"] = 0 }
	chess.look = { ["x"] = 0, ["y"] = 0 }
	chess:ResetAvailable()
	chess:AddHooks()
	chess:CheckKing()
end)
net.Receive('Chess_ResetGame', function()
	local chess = Entity(net.ReadUInt(32))
	if not IsValid(chess) then return end
	chess:ResetGameCl()
end)
net.Receive('Chess_RemoveFGame', function()
	local chess = Entity(net.ReadUInt(32))
	if not IsValid(chess) then return end
	hook.Remove( "KeyPress", chess )
end)
net.Receive('Chess_SendData', function()
	local chess = Entity(net.ReadUInt(32))
	if not IsValid(chess) then return end
	chess.brd_data = net.ReadTable()
end)
net.Receive('Chess_Step', function()
	local chess = Entity(net.ReadUInt(32))
	if not IsValid(chess) then return end
	chess:ChangeStep(net.ReadTable(),net.ReadBit()*2)
end)
net.Receive('Chess_ChangePiece', function()
	local chess = Entity(net.ReadUInt(32))
	if not IsValid(chess) then return end
	local ind = net.ReadUInt(32)
	if not chess.mdls or not chess.mdls.piece or not IsValid(chess.mdls.piece[ind]) then
		if not chess.piecechange then
			chess.piecechange = {}
		end
		if ind <= 16 then
			chess.piecechange[ind] = 5
		else
			chess.piecechange[ind] = 11
		end
	else
		if chess.mdls.piece[ind].SetNoDraw then
			chess.mdls.piece[ind]:Remove()
		end
		if ind <= 16 then
			chess.mdls.piece[ind] = ClientsideModel(ChessModels[5], RENDERGROUP_OPAQUE)
		else
			chess.mdls.piece[ind] = ClientsideModel(ChessModels[11], RENDERGROUP_OPAQUE)
		end
		chess.mdls.piece[ind]:SetNoDraw(true)
		chess.mdls.piece[ind]:SetPos(chess:GetPos())
		local mat = Matrix()
		mat:Scale(Vector(0.44, 0.44, 0.44))
		chess.mdls.piece[ind]:EnableMatrix("RenderMultiply", mat)
	end
end)

function ENT:Initialize()
	self.available = {}
	self.brd_data = {}
	self.sel = { ["x"] = 0, ["y"] = 0 }
	self.look = { ["x"] = 0, ["y"] = 0 }
	self.kwarn = { ["x"] = 0, ["y"] = 0 }
	self.piece = {
		["type"] = {},
		["moved"] = {}
	}
	for i=1,32 do
		self.piece.moved[i] = false
	end
	self:ResetBrdData()
	
	net.Start( 'Chess_SendData' )
		net.WriteUInt( self:EntIndex(), 32 )
		net.WriteEntity( LocalPlayer() )
	net.SendToServer()
end

function ENT:AddHooks()
	local last_time = RealTime()
	hook.Add("KeyPress", self, function(self, ply, key)
		if not IsValid(self) then return end
		if key == IN_RELOAD and self:GetTableOwner() == ply and RealTime() - last_time > 3 then
			if self:GetTableOwner() == ply then
				net.Start( 'Chess_ResetGame' )
					net.WriteUInt( self:EntIndex(), 32 )
					net.WriteEntity( LocalPlayer() )
				net.SendToServer()
				last_time = RealTime()
			end
		end
		if key == IN_ATTACK and self:GetTurnPly() == ply and self.look.x != 0 and self.look.y != 0 then
			if self.available[self.look.x][self.look.y] then
				self:MovePiece(self.look.x,self.look.y)
			else
				if self.brd_data[self.look.x][self.look.y] != 0 then
					self:CheckPiece( self.look.x, self.look.y )
				end
			end
		end
	end)
end

function ENT:CreateModels()
	self.mdls = {}
	self.mdls.brd = ClientsideModel("models/props_phx/games/chess/board.mdl", RENDERGROUP_OPAQUE)
	self.mdls.brd:SetNoDraw(true)
	self.mdls.brd:SetPos(self:GetPos())
	local matbrd = Matrix()
	matbrd:Scale(Vector(0.36, 0.36, 0.36))
	self.mdls.brd:EnableMatrix("RenderMultiply", matbrd)
	
	self.mdls.piece = {
		[1]  = ClientsideModel(ChessModels[1], RENDERGROUP_OPAQUE),
		[2]  = ClientsideModel(ChessModels[2], RENDERGROUP_OPAQUE),
		[3]  = ClientsideModel(ChessModels[3], RENDERGROUP_OPAQUE),
		[4]  = ClientsideModel(ChessModels[4], RENDERGROUP_OPAQUE),
		[5]  = ClientsideModel(ChessModels[5], RENDERGROUP_OPAQUE),
		[6]  = ClientsideModel(ChessModels[3], RENDERGROUP_OPAQUE),
		[7]  = ClientsideModel(ChessModels[2], RENDERGROUP_OPAQUE),
		[8]  = ClientsideModel(ChessModels[1], RENDERGROUP_OPAQUE),
		[9]  = ClientsideModel(ChessModels[6], RENDERGROUP_OPAQUE),
		[10] = ClientsideModel(ChessModels[6], RENDERGROUP_OPAQUE),
		[11] = ClientsideModel(ChessModels[6], RENDERGROUP_OPAQUE),
		[12] = ClientsideModel(ChessModels[6], RENDERGROUP_OPAQUE),
		[13] = ClientsideModel(ChessModels[6], RENDERGROUP_OPAQUE),
		[14] = ClientsideModel(ChessModels[6], RENDERGROUP_OPAQUE),
		[15] = ClientsideModel(ChessModels[6], RENDERGROUP_OPAQUE),
		[16] = ClientsideModel(ChessModels[6], RENDERGROUP_OPAQUE),
		[17] = ClientsideModel(ChessModels[7], RENDERGROUP_OPAQUE),
		[18] = ClientsideModel(ChessModels[8], RENDERGROUP_OPAQUE),
		[19] = ClientsideModel(ChessModels[9], RENDERGROUP_OPAQUE),
		[20] = ClientsideModel(ChessModels[10], RENDERGROUP_OPAQUE),
		[21] = ClientsideModel(ChessModels[11], RENDERGROUP_OPAQUE),
		[22] = ClientsideModel(ChessModels[9], RENDERGROUP_OPAQUE),
		[23] = ClientsideModel(ChessModels[8], RENDERGROUP_OPAQUE),
		[24] = ClientsideModel(ChessModels[7], RENDERGROUP_OPAQUE),
		[25] = ClientsideModel(ChessModels[12], RENDERGROUP_OPAQUE),
		[26] = ClientsideModel(ChessModels[12], RENDERGROUP_OPAQUE),
		[27] = ClientsideModel(ChessModels[12], RENDERGROUP_OPAQUE),
		[28] = ClientsideModel(ChessModels[12], RENDERGROUP_OPAQUE),
		[29] = ClientsideModel(ChessModels[12], RENDERGROUP_OPAQUE),
		[30] = ClientsideModel(ChessModels[12], RENDERGROUP_OPAQUE),
		[31] = ClientsideModel(ChessModels[12], RENDERGROUP_OPAQUE),
		[32] = ClientsideModel(ChessModels[12], RENDERGROUP_OPAQUE)
	}
	
	--just testing something
	
	if self.piecechange and type(self.piecechange) == "table" then
		for k,v in pairs(self.piecechange) do
			self.mdls.piece[k] = ClientsideModel(ChessModels[v], RENDERGROUP_OPAQUE)
		end
	end
	
	for k,v in pairs(self.mdls.piece) do
		v:SetNoDraw(true)
		v:SetPos(self:GetPos())
		local mat = Matrix()
		mat:Scale(Vector(0.44, 0.44, 0.44))
		v:EnableMatrix("RenderMultiply", mat)
	end
end

function ENT:ResetAvailable()
	for i=1,8 do
		self.available[i] = {}
		for j=1,8 do
			self.available[i][j] = false
		end
	end
end

function ENT:ResetGameCl()
	self.sel.x = 0
	self.sel.y = 0
	self:CreateModels()
	self:ResetBrdData()
	self:ResetAvailable()
	for i=1,32 do
		self.piece.moved[i] = false
	end
	self.piece.type[1] = 1
	self.piece.type[2] = 2
	self.piece.type[3] = 3
	self.piece.type[4] = 4
	self.piece.type[5] = 5
	self.piece.type[6] = 3
	self.piece.type[7] = 2
	self.piece.type[8] = 1
	self.piece.type[9] = 0
	self.piece.type[10] = 0
	self.piece.type[11] = 0
	self.piece.type[12] = 0
	self.piece.type[13] = 0
	self.piece.type[14] = 0
	self.piece.type[15] = 0
	self.piece.type[16] = 0
	self.piece.type[17] = 1
	self.piece.type[18] = 2
	self.piece.type[19] = 3
	self.piece.type[20] = 4
	self.piece.type[21] = 5
	self.piece.type[22] = 3
	self.piece.type[23] = 2
	self.piece.type[24] = 1
	self.piece.type[25] = 0
	self.piece.type[26] = 0
	self.piece.type[27] = 0
	self.piece.type[28] = 0
	self.piece.type[29] = 0
	self.piece.type[30] = 0
	self.piece.type[31] = 0
	self.piece.type[32] = 0
end

function ENT:Think()
	if LocalPlayer() != self:GetTurnPly() then return end
	
	local piecepos,pieceang = LocalToWorld(Vector(0.1, 0, 34.5), Angle(0, 180, 0), self:GetPos(), self:GetAngles())
	local vec = util.IntersectRayWithPlane(LocalPlayer():EyePos(), LocalPlayer():EyeAngles():Forward(), piecepos, pieceang:Up())
	
	if vec == nil then return end
	
	local brpos,brang = WorldToLocal(vec, Angle(), self:GetPos(), self:GetAngles())
	local posx = math.ceil( brpos.X / 4.2 + 4 )
	local posy = math.ceil( brpos.Y / 4.2 + 4 )
	
	if posx > 8 or posx < 1 or posy > 8 or posy < 1 then return end
	
	self.look.x = posx
	self.look.y = posy
end

function ENT:MovePiece(x,y)
	net.Start( 'Chess_MovePiece' )
		net.WriteUInt( self:EntIndex(), 32 )
		net.WriteEntity( LocalPlayer() )
		net.WriteUInt( self.sel.x, 32 )
		net.WriteUInt( self.sel.y, 32 )
		net.WriteUInt( x, 32 )
		net.WriteUInt( y, 32 )
	net.SendToServer()
	self.sel.x = 0
	self.sel.y = 0
	self.kwarn = { ["x"] = 0, ["y"] = 0 }
	self:ResetAvailable()
end

function ENT:CheckKing()
	local ind, x, y, i, j, blocked
	
	if LocalPlayer() == self:GetPly1() then ind = 4
	elseif LocalPlayer() == self:GetPly2() then ind = 20
	else return false end
	
	for i=1,8 do
		for j=1,8 do
			if self.brd_data[i][j] == ind then
				x = i
				y = j
				break
			end
		end
	end
	
	i = x
	j = y
	blocked = false
	while !blocked and i<8 do
		i = i + 1
		if self.brd_data[i][j] != 0 then
			blocked = true
			if ((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
				if self.piece.type[self.brd_data[i][j]] == 1 or self.piece.type[self.brd_data[i][j]] == 5 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x
	j = y
	blocked = false
	while !blocked and i>1 do
		i = i - 1
		if self.brd_data[i][j] != 0 then
			blocked = true
			if ((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
				if self.piece.type[self.brd_data[i][j]] == 1 or self.piece.type[self.brd_data[i][j]] == 5 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x
	j = y
	blocked = false
	while !blocked and j<8 do
		j = j + 1
		if self.brd_data[i][j] != 0 then
			blocked = true
			if ((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
				if self.piece.type[self.brd_data[i][j]] == 1 or self.piece.type[self.brd_data[i][j]] == 5 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x
	j = y
	blocked = false
	while !blocked and j>1 do
		j = j - 1
		if self.brd_data[i][j] != 0 then
			blocked = true
			if ((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
				if self.piece.type[self.brd_data[i][j]] == 1 or self.piece.type[self.brd_data[i][j]] == 5 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end

	i = x+2
	j = y+1
	if i <= 8 and j <= 8 then
		if self.brd_data[i][j] != 0 then
			if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
				if self.piece.type[self.brd_data[i][j]] == 2 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x+2
	j = y-1
	if i <= 8 and j >= 1 then
		if self.brd_data[i][j] != 0 then
			if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
				if self.piece.type[self.brd_data[i][j]] == 2 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x-2
	j = y+1
	if i >= 1 and j <= 8 then
		if self.brd_data[i][j] != 0 then
			if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
				if self.piece.type[self.brd_data[i][j]] == 2 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x-2
	j = y-1
	if i >= 1 and j >= 1 then
		if self.brd_data[i][j] != 0 then
			if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
				if self.piece.type[self.brd_data[i][j]] == 2 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x+1
	j = y+2
	if i <= 8 and j <= 8 then
		if self.brd_data[i][j] != 0 then
			if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
				if self.piece.type[self.brd_data[i][j]] == 2 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x-1
	j = y+2
	if i >= 1 and j <= 8 then
		if self.brd_data[i][j] != 0 then
			if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
				if self.piece.type[self.brd_data[i][j]] == 2 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x+1
	j = y-2
	if i <= 8 and j >= 1 then
		if self.brd_data[i][j] != 0 then
			if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
				if self.piece.type[self.brd_data[i][j]] == 2 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x-1
	j = y-2
	if i >= 1 and j >= 1 then
		if self.brd_data[i][j] != 0 then
			if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
				if self.piece.type[self.brd_data[i][j]] == 2 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end

	i = x
	j = y
	blocked = false
	while !blocked and i < 8 and j > 1 do
		i = i + 1
		j = j - 1
		if self.brd_data[i][j] != 0 then
			blocked = true
			if ((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
				if self.piece.type[self.brd_data[i][j]] == 3 or self.piece.type[self.brd_data[i][j]] == 5 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x
	j = y
	blocked = false
	while !blocked and i < 8 and j < 8 do
		i = i + 1
		j = j + 1
		if self.brd_data[i][j] != 0 then
			blocked = true
			if ((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
				if self.piece.type[self.brd_data[i][j]] == 3 or self.piece.type[self.brd_data[i][j]] == 5 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x
	j = y
	blocked = false
	while !blocked and i > 1 and j < 8 do
		i = i - 1
		j = j + 1
		if self.brd_data[i][j] != 0 then
			blocked = true
			if ((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
				if self.piece.type[self.brd_data[i][j]] == 3 or self.piece.type[self.brd_data[i][j]] == 5 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	i = x
	j = y
	blocked = false
	while !blocked and i > 1 and j > 1 do
		i = i - 1
		j = j - 1				
		if self.brd_data[i][j] != 0 then
			blocked = true
			if ((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
				if self.piece.type[self.brd_data[i][j]] == 3 or self.piece.type[self.brd_data[i][j]] == 5 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	
	if ind <= 16 then
		i = x - 1
		j = y - 1
		if i >= 1 and j >= 1 then
			if self.brd_data[i][j] > 16 then
				if self.piece.type[self.brd_data[i][j]] == 0 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
		i = x + 1
		j = y - 1
		if i <= 8 and j >= 1 then
			if self.brd_data[i][j] > 16 then
				if self.piece.type[self.brd_data[i][j]] == 0 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	else
		i = x + 1
		j = y + 1
		if i <= 8 and j <= 8 then
			if self.brd_data[i][j] <= 16 and self.brd_data[i][j] != 0 then
				if self.piece.type[self.brd_data[i][j]] == 0 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
		i = x - 1
		j = y + 1
		if i >= 1 and j <= 8 then
			if self.brd_data[i][j] <= 16 and self.brd_data[i][j] != 0 then
				if self.piece.type[self.brd_data[i][j]] == 0 then self.kwarn = { ["x"] = x, ["y"] = y } return end
			end
		end
	end
	self.kwarn = { ["x"] = 0, ["y"] = 0 }
	return
end

function ENT:CheckPiece( x, y )
	local ind = self.brd_data[x][y]
	local i, j
	if (self:GetTableTurn() == 1 and ind > 16) or (self:GetTableTurn() == 2 and ind <= 16) then return end
	
	self.sel.x = x
	self.sel.y = y
	
	self:ResetAvailable()
	
	local function RookMove()
		local i, j, blocked
		i = x
		j = y
		blocked = false
		while !blocked and i<8 do
			i = i + 1
			if self.brd_data[i][j] != 0 then
				blocked = true
				if !((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
					i = i - 1
				end
			end
			self.available[i][j] = true
		end
		i = x
		j = y
		blocked = false
		while !blocked and i>1 do
			i = i - 1
			if self.brd_data[i][j] != 0 then
				blocked = true
				if !((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
					i = i + 1
				end
			end
			self.available[i][j] = true
		end
		i = x
		j = y
		blocked = false
		while !blocked and j<8 do
			j = j + 1
			if self.brd_data[i][j] != 0 then
				blocked = true
				if !((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
					j = j - 1
				end
			end
			self.available[i][j] = true
		end
		i = x
		j = y
		blocked = false
		while !blocked and j>1 do
			j = j - 1
			if self.brd_data[i][j] != 0 then
				blocked = true
				if !((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
					j = j + 1
				end
			end
			self.available[i][j] = true
		end
	end
	local function KnightMove()
		local i, j
		i = x+2
		j = y+1
		if i <= 8 and j <= 8 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		i = x+2
		j = y-1
		if i <= 8 and j >= 1 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		i = x-2
		j = y+1
		if i >= 1 and j <= 8 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		i = x-2
		j = y-1
		if i >= 1 and j >= 1 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		i = x+1
		j = y+2
		if i <= 8 and j <= 8 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		i = x-1
		j = y+2
		if i >= 1 and j <= 8 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		i = x+1
		j = y-2
		if i <= 8 and j >= 1 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		i = x-1
		j = y-2
		if i >= 1 and j >= 1 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
	end
	local function BishopMove()
		local i, j, blocked
		i = x
		j = y
		blocked = false
		while !blocked and i < 8 and j > 1 do
			i = i + 1
			j = j - 1
			if self.brd_data[i][j] != 0 then
				blocked = true
				if !((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
					i = i - 1
					j = j + 1
				end
			end
			self.available[i][j] = true
		end
		i = x
		j = y
		blocked = false
		while !blocked and i < 8 and j < 8 do
			i = i + 1
			j = j + 1
			if self.brd_data[i][j] != 0 then
				blocked = true
				if !((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
					i = i - 1
					j = j - 1
				end
			end
			self.available[i][j] = true
		end
		i = x
		j = y
		blocked = false
		while !blocked and i > 1 and j < 8 do
			i = i - 1
			j = j + 1
			if self.brd_data[i][j] != 0 then
				blocked = true
				if !((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
					i = i + 1
					j = j - 1
				end
			end
			self.available[i][j] = true
		end
		i = x
		j = y
		blocked = false
		while !blocked and i > 1 and j > 1 do
			i = i - 1
			j = j - 1				
			if self.brd_data[i][j] != 0 then
				blocked = true
				if !((ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16)) then
					i = i + 1
					j = j + 1
				end
			end
			self.available[i][j] = true
		end
	end
	
	if self.piece.type[ind] == 1 then
		RookMove()
	elseif self.piece.type[ind] == 2 then
		KnightMove()
	elseif self.piece.type[ind] == 3 then
		BishopMove()
	elseif self.piece.type[ind] == 4 then
	//
	// King
	//
		//0+
		i = x
		j = y + 1
		if j <= 8 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		//0-
		i = x
		j = y - 1
		if j >= 1 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		//++
		i = x + 1
		j = y + 1
		if i <= 8 and j <= 8 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		//+-
		i = x + 1
		j = y - 1
		if i <= 8 and j >= 1 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		//-+
		i = x - 1
		j = y + 1
		if i >= 1 and j <= 8 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		//--
		i = x - 1
		j = y - 1
		if i >= 1 and j >= 1 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		//+0
		i = x + 1
		j = y
		if i <= 8 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		//-0
		i = x - 1
		j = y
		if i >= 1 then
			if self.brd_data[i][j] == 0 then
				self.available[i][j] = true
			else
				if (ind <= 16 and self.brd_data[i][j] > 16) or (ind > 16 and self.brd_data[i][j] <= 16) then
					self.available[i][j] = true
				end
			end
		end
		// special
		if !self.piece.moved[self.brd_data[x][y]] then
			if x == 4 and y == 8 then
				if self.brd_data[1][8] == 1 then
					if !self.piece.moved[1] then
						if self.brd_data[3][8] == 0 and self.brd_data[2][8] == 0 then
							self.available[2][8] = true
						end
					end
				elseif self.brd_data[8][8] == 8 then
					if !self.piece.moved[8] then
						if self.brd_data[5][8] == 0 and self.brd_data[6][8] == 0 and self.brd_data[7][8] == 0 then
							self.available[6][8] = true
						end
					end
				end
			end
			if x == 4 and y == 1 then
				if self.brd_data[1][1] == 17 then
					if !self.piece.moved[17] then
						if self.brd_data[3][1] == 0 and self.brd_data[2][1] == 0 then
							self.available[2][1] = true
						end
					end
				elseif self.brd_data[8][1] == 24 then
					if !self.piece.moved[24] then
						if self.brd_data[5][1] == 0 and self.brd_data[6][1] == 0 and self.brd_data[7][1] == 0 then
							self.available[6][1] = true
						end
					end
				end
			end
		end
		
	elseif self.piece.type[ind] == 5 then
	//
	//Queen
	//
		RookMove()
		BishopMove()
	else
	//
	// Pawn
	//
		if ind <= 16 then
			//Y-
			i = x
			j = y - 1
			if j >= 1 then
				if self.brd_data[i][j] == 0 then
					self.available[i][j] = true
					if y == 7 then
						if self.brd_data[i][j - 1] == 0 then
							self.available[i][j - 1] = true
						end
					end
				end
			end
			i = x - 1
			j = y - 1
			if i >= 1 and j >= 1 then
				if self.brd_data[i][j] > 16 then
					self.available[i][j] = true
				end
			end
			i = x + 1
			j = y - 1
			if i <= 8 and j >= 1 then
				if self.brd_data[i][j] > 16 then
					self.available[i][j] = true
				end
			end
		else
			//Y+
			i = x
			j = y + 1
			if j <= 8 then
				if self.brd_data[i][j] == 0 then
					self.available[i][j] = true
					if y == 2 then
						if self.brd_data[i][j + 1] == 0 then
							self.available[i][j + 1] = true
						end
					end
				end
			end
			i = x + 1
			j = y + 1
			if i <= 8 and j <= 8 then
				if self.brd_data[i][j] != 0 then
					if self.brd_data[i][j] <= 16 then
						self.available[i][j] = true
					end
				end
			end
			i = x - 1
			j = y + 1
			if i >= 1 and j <= 8 then
				if self.brd_data[i][j] != 0 then
					if self.brd_data[i][j] <= 16 then
						self.available[i][j] = true
					end
				end
			end
		end
	end
	self.available[x][y] = false
end

function SetPosToChess(pos, ang, x, y, z )
	local setvector = Vector(x, y, z)
	setvector:Rotate( ang )
	local setpos = pos + setvector
	return setpos
end

function ENT:Draw()
	self:DrawModel()
	
	if not self.mdls or not IsValid(self.mdls.brd) then self:CreateModels() end
	local boardpos,boardang = LocalToWorld(Vector(0, 0, 32), Angle(-90, 0, 0), self:GetPos(), self:GetAngles())
	self.mdls.brd:SetRenderOrigin(boardpos)
	self.mdls.brd:SetRenderAngles(boardang)
	self.mdls.brd:SetupBones()
	self.mdls.brd:DrawModel()
	
	if LocalPlayer():GetShootPos():Distance(self:GetPos()) > 500 then return end
	
	local piecepos,pieceang = LocalToWorld(Vector(0, 0, 34.5), Angle(0, 0, 0), self:GetPos(), self:GetAngles())
	for i=1,8 do
		for	j=1,8 do
			if self.brd_data[i][j] != 0 then
				local mdl = self.mdls.piece[self.brd_data[i][j]]
				mdl:SetRenderOrigin(SetPosToChess(piecepos, pieceang, brdpos.x[i], brdpos.y[j], 0 ))
				if self.brd_data[i][j] == 2 or self.brd_data[i][j] == 7 then
					local piecepos,pieceang = LocalToWorld(Vector(0, 0, 34.5), Angle(0, -90, 0), self:GetPos(), self:GetAngles())
					mdl:SetRenderAngles(pieceang)
				elseif self.brd_data[i][j] == 18 or self.brd_data[i][j] == 23 then
					local piecepos,pieceang = LocalToWorld(Vector(0, 0, 34.5), Angle(0, 90, 0), self:GetPos(), self:GetAngles())
					mdl:SetRenderAngles(pieceang)
				else
					mdl:SetRenderAngles(pieceang)
				end
				mdl:SetupBones()
				mdl:DrawModel()
			end
		end
	end
	
	if IsValid(self:GetPly1()) then
		local ang = self:GetAngles()
		ang:RotateAroundAxis( ang:Up(), 180 )
		cam.Start3D2D( SetPosToChess(self:GetPos(), self:GetAngles(), 0, 20, 32.3 ), ang, 0.2 )
			if self:GetTableTurn() == 1 then
				draw.DrawText( self:GetPly1():Nick(), "ChessGameFontPlayer", 0, 0, Color( 0, 255, 0 ), 1 )
			else
				draw.DrawText( self:GetPly1():Nick(), "ChessGameFontPlayer", 0, 0, Color( 255, 0, 0 ), 1 )
			end
			if self:GetTableOwner() == self:GetPly1() then
				draw.DrawText("Owner", "ChessGameFontPlayer", 0, 20, Color(255, 255, 0), TEXT_ALIGN_CENTER)
			end
		cam.End3D2D()
	end
	if IsValid(self:GetPly2()) then
		cam.Start3D2D( SetPosToChess(self:GetPos(), self:GetAngles(), 0, -20, 32.3 ), self:GetAngles(), 0.2 )
			if self:GetTableTurn() == 2 then
				draw.DrawText( self:GetPly2():Nick(), "ChessGameFontPlayer", 0, 0, Color( 0, 255, 0 ), 1 )
			else
				draw.DrawText( self:GetPly2():Nick(), "ChessGameFontPlayer", 0, 0, Color( 255, 0, 0 ), 1 )
			end
			if self:GetTableOwner() == self:GetPly2() then
				draw.DrawText("Owner", "ChessGameFontPlayer", 0, 20, Color(255, 255, 0), TEXT_ALIGN_CENTER)
			end
		cam.End3D2D()
	end
	
	if LocalPlayer() == self:GetTurnPly() then
		cam.Start3D2D( SetPosToChess(self:GetPos(), self:GetAngles(), 0, 0.2, 34.57 ), self:GetAngles(), 0.085 )
		if self.look.x != 0 and self.look.y != 0 then
			if ( self.brd_data[self.look.x][self.look.y] != 0 and (self:GetTableTurn() == 1 and self.brd_data[self.look.x][self.look.y] < 17) or (self:GetTableTurn() == 2 and self.brd_data[self.look.x][self.look.y] > 16)) then
				surface.SetDrawColor(Color(0,255,0,200))
			else
				surface.SetDrawColor(Color(255,0,0,200))
			end
			surface.DrawRect(rectpos.x[self.look.x] * 10, rectpos.y[self.look.y] * 9.8, 50, 50)
		end
		if self.sel.x != 0 and self.sel.y != 0 then
			surface.SetDrawColor(Color(0,150,0,200))
			surface.DrawRect(rectpos.x[self.sel.x] * 10, rectpos.y[self.sel.y] * 9.8, 50, 50)
			for i=1,8 do
				for j=1,8 do
					if self.available[i][j] == true then
						surface.SetDrawColor(Color(0,0,255,200))
						surface.DrawRect(rectpos.x[i] * 10, rectpos.y[j] * 9.8, 50, 50)
					end
				end
			end
		end
		if self.kwarn.x != 0 and self.kwarn.y != 0 then
			surface.SetDrawColor(Color(255,100,0,200))
			surface.DrawRect(rectpos.x[self.kwarn.x] * 10, rectpos.y[self.kwarn.y] * 9.8, 50, 50)
		end
		cam.End3D2D()
	end
end
 
function ENT:OnRemove()
	if self.mdls.brd.SetNoDraw then
		self.mdls.brd:Remove()
	end
	for k,v in pairs(self.mdls.piece) do
		if v.SetNoDraw then
			v:Remove()
		end
	end
	hook.Remove( "KeyPress", self )
end