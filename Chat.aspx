<%@ Page Language="VB"%>
<% 
    Dim sUserList As String = ""

    If Application("Sockets") IsNot Nothing Then
        For Each oSocket As DictionaryEntry In Application("Sockets")
            Dim sUser As String = oSocket.Key
            sUserList += "<div class='User' data-value=""" & sUser & """>" & sUser & "</div>" & vbCrLf
        Next
    End If

    If Request.QueryString("getUsers") = "1" Then
        Response.Write(sUserList)
        Response.End()

    ElseIf Request.QueryString("resetUsers") = "1" Then

        If Application("Sockets") IsNot Nothing Then
            For Each oEntry As DictionaryEntry In Application("Sockets")
                Dim oSocket As Object = oEntry.Value

                Try
                    oSocket.CloseOutputAsync(System.Net.WebSockets.WebSocketCloseStatus.NormalClosure, "", System.Threading.CancellationToken.None)
                    oSocket.CloseAsync(System.Net.WebSockets.WebSocketCloseStatus.NormalClosure, "", System.Threading.CancellationToken.None)
                Catch ex As Exception
                    'System.Threading.Thread.Sleep(1000)
                End Try

            Next

            Application("Sockets") = Nothing
        End If

        Response.Write("Users reseted")
        Response.End()

    End If
%>
<!DOCTYPE html>
<html>
    <head>
        <title>Chat App</title>
        <script src="Chat.js?v=13"></script>
    </head>
    <body onload="OnLoad()">       

        <div id="idContainer">
            <table style="width: 100%;">
                <tr>
                    <td>
                        <label for="txtUser">User Name</label>
                        <input id="txtUser" value="<%=IIf(Request.QueryString("user") <> "", Request.QueryString("user"), "Jack")%>" />

                        <button type="button" onclick="OpenSocket()" id="btnOpen">Login</button>
                        <button type="button" onclick="CloseSocket()" id="btnClose" disabled>Log off</button>

                        <span id="spStatus" style="color:red">&#11044;</span>

                    </td>
                    <td align="right">
                        <table border="0">
                            <tr>
                                <td>
                                    <label>Users</label></td>
                                <td>
                                    <button type="button" onclick="RefreshUsers()" title="Refresh Users">&#x21bb;</button>
                                </td>
                                <td>
                                    <button type="button" onclick="ResetUsers()" title="Reset Users">&#9728;</button>
                                </td>
                            </tr>
                        </table>                     
                    </td>
                </tr>

                <tr>
                    <td style="width: 78%; height: 100%; padding-right: 10px; padding-bottom: 5px; height: 300px">
                        <textarea id="txtOutput" rows="1" style="margin-top: 10px; width: 100%; height: 100%" placeholder="Output"></textarea>
                    </td>

                    <td id="tdOtherUsers" style="width: 20%; height: 100%; padding-left: 10px; border: 1px solid gray; vertical-align: top">
                        <%=sUserList%>
                    </td>
                </tr>
            </table>
            

        <textarea id="txtMsg" rows="5" wrap="soft" style="width: 98%; margin-left: 3px; margin-top: 6px" placeholder="Input Text"></textarea>


        <table border="0">
            <tr>
                <td>
                    <button type="button" onclick="Send()" id="btnSend" disabled>Send</button> 
                </td>
                <td>
                    <button type="button" onclick="Ring()" id="btnRing" title="Ring" disabled>&#9742;</button>
                </td>
                <td>
                    <button type="button" onmousedown="RecordStart()" onmouseup="RecordEnd()"  onmouseout="RecordEnd()" id="btnPushToTalk" disabled>Push-to-talk</button> 
                </td>
                <td>
                    <label>
                        <input type="checkbox" id="chkSendAudio" onclick="SetupAutoSound()" disabled/> Auto detect            
                    </label>
                </td>
                <td id="tdSound" style="display:none">
                    <table>
                        <tr>
                            <td>
                                <label>
                                    <input type="checkbox" id="chkSoundSettings" onclick="SoundSettings()"/> Settings          
                                </label>
                            </td>
                            <td style="width: 50px" title="Volume">
                                <div id="idVolume"></div>
                            </td>
                            <td style="width: 100px" title="Volume State">
                                <div id="idVolumeState"></div>
                            </td>
                            <td style="width: 90px" title="Recorder State">
                                <div id="idMediaRecorderState"></div>
                            </td>
                            <td>
                                <div id="idProgress" style="width: 200px; height:10px; border: 1px solid green; background-color: lightblue; border-radius: 4px;"></div>
                            </td>
                        </tr>
                    </table>
                </td>

            </tr>
        </table>


        <%
            Dim oList As New ArrayList()
            oList.Add("averageSignalValue")
            oList.Add("speakingMinVolume")
            oList.Add("muteVolume")
            oList.Add("signalDuration")
            oList.Add("maxSignalDuration")
            oList.Add("silence")
            oList.Add("prespeechstartMsecs")
        %>

        <table id="tblSoundSettings" style="display:none; border: 1px solid gray; border-radius: 3px;">
            <%For each sItem As String In oList %>
            <tr>
                <td><%=sItem%></td>
                <td>
                    <input id="txt_<%=sItem%>" type="range" 
                        <%If Right(sItem, 5) = "Value" Or Right(sItem, 6) = "Volume" Then%>
                        min="0" max="0.09" step="0.001" 
                        <%Else %>
                        min="1" max="<%=IIf(sItem = "maxSignalDuration", 10000, 3000) %>" step="1"
                        <%End If %>
                        onchange="config.<%=sItem%>=parseFloat(this.value); id_<%=sItem%>.innerHTML=this.value" />
                </td>
                <td id="id_<%=sItem%>"></td>
            </tr>
            <%Next %>            
        </table>

        </div>  

        
        <audio id="idAudio" controls></audio>

    </body>
</html>
