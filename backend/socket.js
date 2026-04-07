const { Server } = require("socket.io");
const { v4: uuidv4 } = require('uuid');

let io;
let waitingQueue = [];
let activeRooms = {}; // socketId -> roomId
let roomDetails = {}; // roomId -> { users: { socketId: profile } }

const initSocket = (server) => {
    io = new Server(server, {
        cors: {
            origin: "*", // allow all or specify your github pages domain here later
            methods: ["GET", "POST"]
        }
    });

    io.on('connection', (socket) => {
        console.log(`User connected: ${socket.id}`);

        socket.on('find_partner', (data) => {
            const { profile, filters } = data;
            console.log(`User ${profile.nickname} looking for partner...`);
            
            // Check if user is already in a room or queue
            if (activeRooms[socket.id]) return;
            waitingQueue = waitingQueue.filter(u => u.socket.id !== socket.id);

            // Attempt matching
            const matchIndex = waitingQueue.findIndex(waitingUser => {
                // A very simple filter logic. In a real app, logic would be bidirectional.
                // E.g. Check if waitingUser.profile matches this user's filters, 
                // and if this user's profile matches waitingUser's filters.
                let match = true;
                if (filters && filters.gender && waitingUser.profile.gender !== filters.gender) match = false;
                if (waitingUser.filters && waitingUser.filters.gender && profile.gender !== waitingUser.filters.gender) match = false;
                
                return match;
            });

            if (matchIndex !== -1) {
                // Partner found!
                const partner = waitingQueue.splice(matchIndex, 1)[0];
                const roomId = uuidv4();

                // Join both to the socket room
                socket.join(roomId);
                partner.socket.join(roomId);

                activeRooms[socket.id] = roomId;
                activeRooms[partner.socket.id] = roomId;

                roomDetails[roomId] = {
                    users: {
                        [socket.id]: profile,
                        [partner.socket.id]: partner.profile
                    }
                };

                // Notify both
                io.to(socket.id).emit('partner_found', { partner: partner.profile });
                io.to(partner.socket.id).emit('partner_found', { partner: profile });
                console.log(`Matched ${socket.id} with ${partner.socket.id} in room ${roomId}`);
            } else {
                // No match, add to queue
                waitingQueue.push({ socket, profile, filters });
            }
        });

        const notifyPartnerLeft = (roomId, excludeSocketId) => {
            if (roomId) {
                socket.to(roomId).emit('partner_left', { message: 'Partner has left the chat.' });
                
                // Cleanup Room
                if (roomDetails[roomId]) {
                    Object.keys(roomDetails[roomId].users).forEach(uid => {
                        delete activeRooms[uid];
                        const s = io.sockets.sockets.get(uid);
                        if (s) s.leave(roomId);
                    });
                    delete roomDetails[roomId];
                }
            }
        };

        socket.on('next', (data) => {
            const roomId = activeRooms[socket.id];
            notifyPartnerLeft(roomId, socket.id);
            // After cleaning up, they will automatically emit 'find_partner' from client
        });

        socket.on('end', () => {
            const roomId = activeRooms[socket.id];
            notifyPartnerLeft(roomId, socket.id);
        });

        socket.on('send_message', (data) => {
            const roomId = activeRooms[socket.id];
            if (roomId) {
                // data contains type (text, image, voice, sticker) and content
                socket.to(roomId).emit('receive_message', data);
            }
        });

        socket.on('typing', (data) => {
            const roomId = activeRooms[socket.id];
            if (roomId) {
                socket.to(roomId).emit('typing', { isTyping: data.isTyping });
            }
        });

        socket.on('disconnect', () => {
            console.log(`User disconnected: ${socket.id}`);
            const roomId = activeRooms[socket.id];
            if (roomId) {
                notifyPartnerLeft(roomId, socket.id);
            }
            waitingQueue = waitingQueue.filter(u => u.socket.id !== socket.id);
        });
    });
};

module.exports = { initSocket };
