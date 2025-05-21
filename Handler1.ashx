<%@ WebHandler Language="VB" Class="Handler1" %>
Imports System.Web
Imports System.Web.Services
Imports System.Net.WebSockets
Imports System.Web.WebSockets
Imports System.Threading.Tasks

Public Class Handler1
    Implements System.Web.IHttpHandler

    Private oSockets As New Hashtable

    Sub ProcessRequest(ByVal context As HttpContext) Implements IHttpHandler.ProcessRequest
        If context.IsWebSocketRequest Then

            If context.Application("Sockets") IsNot Nothing Then
                oSockets = context.Application("Sockets")

                Dim sUserId As String = context.Request.QueryString("user")
                If oSockets.ContainsKey(sUserId) Then
                    context.Response.StatusCode = 500
                    context.Response.StatusDescription = "User " & sUserId & " already logged in"
                    context.Response.End()
                End If

            End If

            Try
                context.AcceptWebSocketRequest(AddressOf HandleSocketRequest)
            Catch ex As Exception
                context.Response.StatusCode = 500
                context.Response.StatusDescription = ex.Message
                context.Response.End()
            End Try

        End If
    End Sub

    Async Function HandleSocketRequest(context As System.Web.WebSockets.AspNetWebSocketContext) As Task
        Dim sUserId As String = context.QueryString("user")
        Dim oSocket As System.Net.WebSockets.WebSocket = context.WebSocket

        'Register user
        oSockets(sUserId) = oSocket
        context.Application("Sockets") = oSockets

        'Send RefreshUsers Msg to all users
        Dim oRefreshMsgBuffer As New ArraySegment(Of Byte)(Encoding.UTF8.GetBytes("{{RefreshUsers}}"))
        For Each oKey As DictionaryEntry In oSockets
            Dim oSocket2 As System.Net.WebSockets.WebSocket = oKey.Value
            Await oSocket2.SendAsync(oRefreshMsgBuffer, WebSocketMessageType.Text, True, Threading.CancellationToken.None)
        Next

        Const iMaxBufferSize As Integer = 64 * 1024
        Dim buffer = New Byte(iMaxBufferSize - 1) {}

        While oSocket.State = WebSocketState.Open 'Loop if Socket is open
            'Get Msg
            Dim result = Await oSocket.ReceiveAsync(New ArraySegment(Of Byte)(buffer), Threading.CancellationToken.None)
            Dim oBytes As Byte() = New Byte(result.Count - 1) {}
            Array.Copy(buffer, oBytes, result.Count)
            Dim oFinalBuffer As List(Of Byte) = New List(Of Byte)()
            oFinalBuffer.AddRange(oBytes)

            'Get Remaining Msg
            While result.EndOfMessage = False
                result = Await oSocket.ReceiveAsync(New ArraySegment(Of Byte)(buffer), Threading.CancellationToken.None)
                oBytes = New Byte(result.Count - 1) {}
                Array.Copy(buffer, oBytes, result.Count)
                oFinalBuffer.AddRange(oBytes)
            End While

            If result.MessageType = WebSocketMessageType.Text Then
                Dim sMsg As String = Encoding.UTF8.GetString(oFinalBuffer.ToArray())
                Dim bSendMsgToAllUsers As Boolean = sMsg <> "{{Ring}}"  'Send Msg to all users (incuding self)

                sMsg = sUserId & ": " & sMsg
                Dim oMsgBuffer As New ArraySegment(Of Byte)(Encoding.UTF8.GetBytes(sMsg))

                For Each oKey As DictionaryEntry In oSockets
                    If bSendMsgToAllUsers OrElse oKey.Key <> sUserId Then
                        Dim oDestSocket As System.Net.WebSockets.WebSocket = oKey.Value
                        Await oDestSocket.SendAsync(oMsgBuffer, WebSocketMessageType.Text, True, Threading.CancellationToken.None)
                    End If
                Next

            ElseIf result.MessageType = WebSocketMessageType.Binary Then
                    Dim oArray As Byte() = oFinalBuffer.ToArray()

                'Send Binary Msg to all users (excluding self)
                For Each oKey As DictionaryEntry In oSockets
                    If oKey.Key <> sUserId Then
                        Dim oDestSocket As System.Net.WebSockets.WebSocket = oKey.Value
                        Dim oMsgBuffer As New ArraySegment(Of Byte)(oArray)
                        Await oDestSocket.SendAsync(oMsgBuffer, WebSocketMessageType.Binary, True, Threading.CancellationToken.None)
                    End If
                Next

            End If
        End While

        'Send RefreshUsers Msg to all users
        For Each oKey As DictionaryEntry In oSockets
            Dim oSocket2 As System.Net.WebSockets.WebSocket = oKey.Value
            Await oSocket2.SendAsync(oRefreshMsgBuffer, WebSocketMessageType.Text, True, Threading.CancellationToken.None)
        Next

        'Close Socket
        Await oSocket.CloseAsync(WebSocketCloseStatus.Empty, "", Threading.CancellationToken.None)

        'Remove Socket from the List
        If oSockets.ContainsKey(sUserId) Then
            oSockets.Remove(sUserId)
            context.Application("Sockets") = oSockets
        End If

    End Function

    ReadOnly Property IsReusable() As Boolean Implements IHttpHandler.IsReusable
        Get
            Return False
        End Get
    End Property

End Class