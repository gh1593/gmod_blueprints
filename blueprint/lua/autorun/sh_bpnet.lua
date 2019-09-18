if SERVER then AddCSLuaFile() end

module("bpnet", package.seeall)

if SERVER then

	local ServerGraph = bpgraph.New()

	local function LoadGraphFromString( graph, str )
		local inStream = bpdata.InStream()
		inStream:LoadString(str, true, true)
		graph:ReadFromStream( inStream )
	end

	local graphData = file.Read("last_server_graph.txt")
	if graphData ~= nil and string.len(graphData) > 0 then
		LoadGraphFromString(ServerGraph, graphData)
	end

	util.AddNetworkString("bpclientcmd")
	util.AddNetworkString("bpservercmd")

	net.Receive("bpservercmd", function(len, ply)

		local cmd = net.ReadUInt(4)

		if cmd == 1 then

			local graphdata = net.ReadString()
			print("BP GRAPH: " .. graphdata)
			file.Write("last_server_graph.txt", graphdata)

			LoadGraphFromString( ServerGraph, graphdata )

			local compiled = bpcompile.Compile( ServerGraph )
			print("Executing blueprint on server...")
			RunString(compiled)

		elseif cmd == 2 then

			local outStream = bpdata.OutStream()
			ServerGraph:WriteToStream(outStream)

			local toSend = outStream:GetString(true, true)

			net.Start("bpclientcmd")
			net.WriteString(toSend)
			net.Send( ply )

		end

	end)

else

	local downloadTarget = nil

	net.Receive("bpclientcmd", function()

		local graphdata = net.ReadString()

		local inStream = bpdata.InStream()
		inStream:LoadString(graphdata, true, true)
		downloadTarget:ReadFromStream( inStream )

	end)

	function DownloadServerGraph( graph )

		downloadTarget = graph

		net.Start("bpservercmd")
		net.WriteUInt(2, 4)
		net.SendToServer()

	end

	function SendGraph( graph )

		bpcompile.Compile( graph )

		net.Start("bpservercmd")
		net.WriteUInt(1, 4)

		local outStream = bpdata.OutStream()
		graph:WriteToStream(outStream)

		local toSend = outStream:GetString(true, true)

		net.WriteString(toSend)
		net.SendToServer()

	end

end