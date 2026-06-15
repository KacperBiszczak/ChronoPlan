import swaggerJsdoc from "swagger-jsdoc";

export const swaggerSpec = swaggerJsdoc({
    definition: {
        openapi: "3.0.0",
        info: {
            title: "ChronoPlan API",
            version: "1.0.0",
            description:
            "Dokumentacja API aplikacji ChronoPlan do planowania wydarzeń, zadań, uczestników i budżetu.",
        },
        servers: [
            {
                url: "http://localhost:5000",
                description: "Local development server",
            },
        ],
        components: {
        securitySchemes: {
            bearerAuth: {
                type: "http",
                scheme: "bearer",
                bearerFormat: "JWT",
            },
        },
        schemas: {
            User: {
            type: "object",
            properties: {
                id: {
                    type: "number",
                    example: 1,
                },
                name: {
                    type: "string",
                    example: "Jan",
                },
                email: {
                    type: "string",
                    example: "jankowalski@test.pl",
                },
                createdAt: {
                    type: "string",
                    example: "2026-01-01T12:00:00.000Z",
                },
            },
            },
            
            LoginRequest: {
            type: "object",
            required: ["email", "password"],
            properties: {
                email: {
                    type: "string",
                    example: "jankowalski@test.pl",
                },
                password: {
                    type: "string",
                    example: "123456",
                },
            },
            },

            RegisterRequest: {
            type: "object",
            required: ["name", "email", "password"],
            properties: {
                name: {
                    type: "string",
                    example: "Jan",
                },
                email: {
                    type: "string",
                    example: "jankowalski@test.pl",
                },
                password: {
                    type: "string",
                    example: "123456",
                },
            },
            },

            AuthResponse: {
            type: "object",
            properties: {
                message: {
                    type: "string",
                    example: "Zalogowano poprawnie",
                },
                token: {
                    type: "string",
                    example: "JWT_TOKEN",
                },
                user: {
                    $ref: "#/components/schemas/User",
                },
            },
            },

            Event: {
                type: "object",
                properties: {
                    id: {
                        type: "number",
                        example: 1,
                    },
                    title: {
                        type: "string",
                        example: "Urodziny",
                    },
                    description: {
                        type: "string",
                        example: "Impreza urodzinowa",
                    },
                    date: {
                        type: "string",
                        format: "date-time",
                    example: "2026-08-01T18:00:00.000Z",
                    },
                    creatorId: {
                        type: "number",
                        example: 1,
                    },
                    createdAt: {
                        type: "string",
                        format: "date-time",
                    },
                    updatedAt: {
                        type: "string",
                        format: "date-time",
                    },
                },
            },

            EventRequest: {
                type: "object",
                required: ["title", "date"],
                properties: {
                    title: {
                        type: "string",
                        example: "Urodziny",
                    },
                    description: {
                        type: "string",
                        example: "Impreza urodzinowa",
                    },
                    date: {
                        type: "string",
                        format: "date-time",
                        example: "2026-08-01T18:00:00.000Z",
                    },
                },
            },

            Task: {
                type: "object",
                properties: {
                    id: {
                        type: "number",
                        example: 1,
                    },
                    title: {
                        type: "string",
                        example: "Zamówić tort",
                    },
                    description: {
                        type: "string",
                        example: "Tort czekoladowy",
                    },
                    status: {
                        type: "string",
                        enum: ["TODO", "IN_PROGRESS", "DONE"],
                        example: "TODO",
                    },
                    eventId: {
                        type: "number",
                        example: 1,
                    },
                    assigneeId: {
                        type: "number",
                        nullable: true,
                        example: null,
                    },
                    createdAt: {
                        type: "string",
                        format: "date-time",
                    },
                    updatedAt: {
                        type: "string",
                        format: "date-time",
                    },
                },
            },

            TaskRequest: {
                type: "object",
                required: ["title", "eventId"],
                properties: {
                    title: {
                        type: "string",
                        example: "Zamówić tort",
                    },
                    description: {
                        type: "string",
                        example: "Tort czekoladowy",
                    },
                    eventId: {
                        type: "number",
                        example: 1,
                    },
                },
            },

            TaskStatusRequest: {
                type: "object",
                required: ["status"],
                properties: {
                    status: {
                        type: "string",
                        enum: ["TODO", "IN_PROGRESS", "DONE"],
                        example: "DONE",
                    },
                },
            },

            Expense: {
                type: "object",
                properties: {
                    id: {
                    type: "number",
                    example: 1,
                    },
                    title: {
                    type: "string",
                    example: "Tort",
                    },
                    amount: {
                    type: "number",
                    example: 250,
                    },
                    eventId: {
                    type: "number",
                    example: 1,
                    },
                    createdAt: {
                    type: "string",
                    format: "date-time",
                    },
                    updatedAt: {
                    type: "string",
                    format: "date-time",
                    },
                },
            },

            ExpenseRequest: {
                type: "object",
                required: ["title", "amount", "eventId"],
                properties: {
                    title: {
                    type: "string",
                    example: "Tort",
                    },
                    amount: {
                    type: "number",
                    example: 250,
                    },
                    eventId: {
                    type: "number",
                    example: 1,
                    },
                },
            },

            ExpenseSummary: {
                type: "object",
                properties: {
                    totalExpenses: {
                    type: "number",
                    example: 250,
                    },
                },
            },

            EventParticipant: {
                type: "object",
                properties: {
                    id: {
                    type: "number",
                    example: 1,
                    },
                    eventId: {
                    type: "number",
                    example: 1,
                    },
                    userId: {
                    type: "number",
                    example: 2,
                    },
                    role: {
                    type: "string",
                    enum: ["ORGANIZER", "PARTICIPANT"],
                    example: "PARTICIPANT",
                    },
                    status: {
                    type: "string",
                    enum: ["INVITED", "ACCEPTED", "DECLINED"],
                    example: "INVITED",
                    },
                    createdAt: {
                    type: "string",
                    format: "date-time",
                    },
                    updatedAt: {
                    type: "string",
                    format: "date-time",
                    },
                },
            },

            InviteParticipantRequest: {
                type: "object",
                required: ["eventId", "email"],
                properties: {
                    eventId: {
                    type: "number",
                    example: 1,
                    },
                    email: {
                    type: "string",
                    example: "adam@test.pl",
                    },
                },
            },

            ParticipantStatusRequest: {
                type: "object",
                required: ["status"],
                properties: {
                    status: {
                    type: "string",
                    enum: ["INVITED", "ACCEPTED", "DECLINED"],
                    example: "ACCEPTED",
                    },
                },
            },
        },
        },
    },
  apis: ["./src/routes/*.ts"],
});