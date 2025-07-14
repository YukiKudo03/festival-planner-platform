class Api::V1::DocsController < Api::V1::BaseController
  skip_before_action :authenticate_api_user!

  # GET /api/v1/docs
  def index
    render json: {
      api_version: "v1",
      documentation: {
        description: "Festival Planner Platform API Documentation",
        version: "1.0.0",
        base_url: request.base_url + "/api/v1",
        authentication: {
          type: "Bearer Token",
          description: "Include API key in Authorization header: Bearer <api_key>",
          endpoints: {
            obtain_token: "POST /auth/login",
            refresh_token: "POST /auth/refresh"
          }
        },
        rate_limiting: {
          default: "1000 requests per hour",
          authenticated: "5000 requests per hour",
          headers: [
            "X-RateLimit-Limit",
            "X-RateLimit-Remaining",
            "X-RateLimit-Reset"
          ]
        },
        endpoints: api_endpoints,
        examples: api_examples,
        error_codes: error_codes,
        changelog: changelog
      }
    }
  end

  # GET /api/v1/docs/openapi
  def openapi
    render json: generate_openapi_spec
  end

  private

  def api_endpoints
    {
      authentication: {
        "POST /api/v1/auth/login" => "User authentication",
        "POST /api/v1/auth/logout" => "User logout",
        "POST /api/v1/auth/refresh" => "Refresh access token"
      },
      users: {
        "GET /api/v1/users/me" => "Get current user profile",
        "GET /api/v1/users/:id" => "Get user by ID",
        "PATCH /api/v1/users/:id" => "Update user profile",
        "GET /api/v1/users/:id/festivals" => "Get user festivals",
        "GET /api/v1/users/:id/tasks" => "Get user tasks",
        "GET /api/v1/users/search" => "Search users"
      },
      festivals: {
        "GET /api/v1/festivals" => "List festivals",
        "POST /api/v1/festivals" => "Create festival",
        "GET /api/v1/festivals/:id" => "Get festival details",
        "PATCH /api/v1/festivals/:id" => "Update festival",
        "DELETE /api/v1/festivals/:id" => "Delete festival",
        "GET /api/v1/festivals/:id/analytics" => "Get festival analytics",
        "POST /api/v1/festivals/:id/join" => "Join festival",
        "DELETE /api/v1/festivals/:id/leave" => "Leave festival"
      },
      tasks: {
        "GET /api/v1/tasks" => "List all user tasks",
        "GET /api/v1/festivals/:festival_id/tasks" => "List festival tasks",
        "POST /api/v1/festivals/:festival_id/tasks" => "Create task",
        "GET /api/v1/tasks/:id" => "Get task details",
        "PATCH /api/v1/tasks/:id" => "Update task",
        "DELETE /api/v1/tasks/:id" => "Delete task",
        "POST /api/v1/tasks/:id/assign" => "Assign task to user",
        "POST /api/v1/tasks/:id/complete" => "Mark task as complete"
      },
      notifications: {
        "GET /api/v1/notifications" => "List notifications",
        "GET /api/v1/notifications/:id" => "Get notification details",
        "PATCH /api/v1/notifications/:id/mark_read" => "Mark notification as read",
        "PATCH /api/v1/notifications/mark_all_read" => "Mark all notifications as read",
        "DELETE /api/v1/notifications/clear_all" => "Clear all notifications",
        "GET /api/v1/notifications/summary" => "Get notifications summary",
        "GET /api/v1/notifications/settings" => "Get notification settings",
        "PATCH /api/v1/notifications/settings" => "Update notification settings"
      },
      payments: {
        "GET /api/v1/payments" => "List payments",
        "GET /api/v1/festivals/:festival_id/payments" => "List festival payments",
        "POST /api/v1/festivals/:festival_id/payments" => "Create payment",
        "GET /api/v1/payments/:id" => "Get payment details",
        "POST /api/v1/payments/:id/confirm" => "Confirm payment"
      },
      integrations: {
        "GET /api/v1/integrations/line" => "List LINE integrations",
        "POST /api/v1/integrations/line" => "Create LINE integration",
        "GET /api/v1/integrations/slack" => "List Slack integrations",
        "POST /api/v1/integrations/slack" => "Create Slack integration"
      },
      webhooks: {
        "POST /api/v1/webhooks/line" => "LINE webhook endpoint",
        "POST /api/v1/webhooks/slack" => "Slack webhook endpoint",
        "POST /api/v1/webhooks/discord" => "Discord webhook endpoint"
      }
    }
  end

  def api_examples
    {
      authentication: {
        login: {
          request: {
            method: "POST",
            url: "/api/v1/auth/login",
            headers: {
              "Content-Type" => "application/json"
            },
            body: {
              email: "user@example.com",
              password: "password123"
            }
          },
          response: {
            access_token: "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
            refresh_token: "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
            user: {
              id: 1,
              name: "John Doe",
              email: "user@example.com"
            }
          }
        }
      },
      tasks: {
        create: {
          request: {
            method: "POST",
            url: "/api/v1/festivals/1/tasks",
            headers: {
              "Authorization" => "Bearer <api_key>",
              "Content-Type" => "application/json"
            },
            body: {
              task: {
                title: "Setup stage equipment",
                description: "Install sound system and lighting",
                priority: "high",
                due_date: "2024-12-25",
                assigned_user_id: 2
              }
            }
          },
          response: {
            task: {
              id: 123,
              title: "Setup stage equipment",
              description: "Install sound system and lighting",
              status: "pending",
              priority: "high",
              due_date: "2024-12-25T00:00:00Z",
              assigned_user: {
                id: 2,
                name: "Jane Smith",
                email: "jane@example.com"
              },
              festival: {
                id: 1,
                name: "Summer Festival 2024"
              },
              created_at: "2024-07-13T10:30:00Z"
            },
            message: "Task created successfully"
          }
        },
        list: {
          request: {
            method: "GET",
            url: "/api/v1/tasks?status=pending&priority=high&page=1&per_page=20",
            headers: {
              "Authorization" => "Bearer <api_key>"
            }
          },
          response: {
            tasks: [
              {
                id: 123,
                title: "Setup stage equipment",
                status: "pending",
                priority: "high",
                due_date: "2024-12-25T00:00:00Z",
                assigned_user: {
                  id: 2,
                  name: "Jane Smith"
                },
                festival: {
                  id: 1,
                  name: "Summer Festival 2024"
                }
              }
            ],
            meta: {
              current_page: 1,
              per_page: 20,
              total_pages: 5,
              total_count: 95
            },
            filters: {
              status: "pending",
              priority: "high"
            }
          }
        }
      },
      notifications: {
        list: {
          request: {
            method: "GET",
            url: "/api/v1/notifications?unread_only=true&page=1",
            headers: {
              "Authorization" => "Bearer <api_key>"
            }
          },
          response: {
            notifications: [
              {
                id: 456,
                title: "Task Assigned",
                message: "You have been assigned to task: Setup stage equipment",
                notification_type: "task_assigned",
                read: false,
                priority: "medium",
                created_at: "2024-07-13T10:30:00Z",
                related_object: {
                  type: "Task",
                  id: 123,
                  name: "Setup stage equipment"
                }
              }
            ],
            meta: {
              current_page: 1,
              per_page: 50,
              total_count: 12
            },
            summary: {
              total_count: 156,
              unread_count: 12,
              types_count: {
                task_assigned: 5,
                task_completed: 3,
                deadline_warning: 4
              }
            }
          }
        }
      }
    }
  end

  def error_codes
    {
      400 => {
        code: "BAD_REQUEST",
        description: "Invalid request parameters",
        example: {
          error: "Invalid request parameters",
          details: {
            title: [ "can't be blank" ],
            due_date: [ "must be a valid date" ]
          }
        }
      },
      401 => {
        code: "UNAUTHORIZED",
        description: "Authentication required or invalid",
        example: {
          error: "Invalid or expired API key"
        }
      },
      403 => {
        code: "FORBIDDEN",
        description: "Access denied to resource",
        example: {
          error: "Access denied to this festival"
        }
      },
      404 => {
        code: "NOT_FOUND",
        description: "Resource not found",
        example: {
          error: "Task not found"
        }
      },
      422 => {
        code: "UNPROCESSABLE_ENTITY",
        description: "Validation errors",
        example: {
          errors: [ "Title can't be blank", "Due date must be in the future" ],
          details: {
            title: [ "can't be blank" ],
            due_date: [ "must be in the future" ]
          }
        }
      },
      429 => {
        code: "TOO_MANY_REQUESTS",
        description: "Rate limit exceeded",
        example: {
          error: "Rate limit exceeded. Try again in 1 hour.",
          retry_after: 3600
        }
      },
      500 => {
        code: "INTERNAL_SERVER_ERROR",
        description: "Server error",
        example: {
          error: "Internal server error",
          message: "An unexpected error occurred"
        }
      }
    }
  end

  def changelog
    [
      {
        version: "1.0.0",
        date: "2024-07-13",
        changes: [
          "Initial API release",
          "User authentication and profile management",
          "Festival and task management",
          "Notification system",
          "Webhook support for LINE and Slack",
          "Payment processing",
          "Comprehensive documentation"
        ]
      }
    ]
  end

  def generate_openapi_spec
    {
      openapi: "3.0.3",
      info: {
        title: "Festival Planner Platform API",
        description: "RESTful API for managing festivals, tasks, and team collaboration",
        version: "1.0.0",
        contact: {
          name: "API Support",
          email: "api-support@festival-planner.com"
        },
        license: {
          name: "MIT",
          url: "https://opensource.org/licenses/MIT"
        }
      },
      servers: [
        {
          url: request.base_url + "/api/v1",
          description: "Production server"
        }
      ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT"
          },
          apiKeyAuth: {
            type: "apiKey",
            in: "header",
            name: "X-API-Key"
          }
        },
        schemas: openapi_schemas
      },
      security: [
        { bearerAuth: [] },
        { apiKeyAuth: [] }
      ],
      paths: openapi_paths,
      tags: [
        { name: "Authentication", description: "User authentication endpoints" },
        { name: "Users", description: "User management" },
        { name: "Festivals", description: "Festival management" },
        { name: "Tasks", description: "Task management" },
        { name: "Notifications", description: "Notification system" },
        { name: "Payments", description: "Payment processing" },
        { name: "Integrations", description: "External service integrations" },
        { name: "Webhooks", description: "Webhook endpoints" }
      ]
    }
  end

  def openapi_schemas
    {
      User: {
        type: "object",
        properties: {
          id: { type: "integer", example: 1 },
          name: { type: "string", example: "John Doe" },
          email: { type: "string", format: "email", example: "john@example.com" },
          role: { type: "string", enum: [ "user", "admin", "system_admin" ], example: "user" },
          created_at: { type: "string", format: "date-time" },
          updated_at: { type: "string", format: "date-time" }
        }
      },
      Festival: {
        type: "object",
        properties: {
          id: { type: "integer", example: 1 },
          name: { type: "string", example: "Summer Festival 2024" },
          description: { type: "string" },
          start_date: { type: "string", format: "date" },
          end_date: { type: "string", format: "date" },
          location: { type: "string" },
          budget: { type: "number", format: "decimal" },
          status: { type: "string", enum: [ "planning", "active", "completed" ] },
          created_at: { type: "string", format: "date-time" },
          updated_at: { type: "string", format: "date-time" }
        }
      },
      Task: {
        type: "object",
        properties: {
          id: { type: "integer", example: 123 },
          title: { type: "string", example: "Setup stage equipment" },
          description: { type: "string" },
          status: { type: "string", enum: [ "pending", "in_progress", "completed" ] },
          priority: { type: "string", enum: [ "low", "medium", "high", "urgent" ] },
          due_date: { type: "string", format: "date-time" },
          progress: { type: "integer", minimum: 0, maximum: 100 },
          assigned_user: { '$ref': "#/components/schemas/User" },
          festival: { '$ref': "#/components/schemas/Festival" },
          created_at: { type: "string", format: "date-time" },
          updated_at: { type: "string", format: "date-time" }
        }
      },
      Notification: {
        type: "object",
        properties: {
          id: { type: "integer", example: 456 },
          title: { type: "string", example: "Task Assigned" },
          message: { type: "string" },
          notification_type: { type: "string" },
          read: { type: "boolean" },
          priority: { type: "string", enum: [ "low", "medium", "high" ] },
          created_at: { type: "string", format: "date-time" },
          read_at: { type: "string", format: "date-time", nullable: true }
        }
      },
      Error: {
        type: "object",
        properties: {
          error: { type: "string" },
          details: { type: "object" },
          timestamp: { type: "string", format: "date-time" }
        }
      },
      PaginationMeta: {
        type: "object",
        properties: {
          current_page: { type: "integer" },
          per_page: { type: "integer" },
          total_pages: { type: "integer" },
          total_count: { type: "integer" }
        }
      }
    }
  end

  def openapi_paths
    {
      "/users/me" => {
        get: {
          tags: [ "Users" ],
          summary: "Get current user profile",
          responses: {
            "200" => {
              description: "User profile",
              content: {
                "application/json" => {
                  schema: {
                    type: "object",
                    properties: {
                      user: { '$ref': "#/components/schemas/User" }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/tasks" => {
        get: {
          tags: [ "Tasks" ],
          summary: "List user tasks",
          parameters: [
            {
              name: "status",
              in: "query",
              schema: { type: "string", enum: [ "pending", "in_progress", "completed" ] }
            },
            {
              name: "priority",
              in: "query",
              schema: { type: "string", enum: [ "low", "medium", "high", "urgent" ] }
            },
            {
              name: "page",
              in: "query",
              schema: { type: "integer", minimum: 1, default: 1 }
            },
            {
              name: "per_page",
              in: "query",
              schema: { type: "integer", minimum: 1, maximum: 100, default: 50 }
            }
          ],
          responses: {
            "200" => {
              description: "List of tasks",
              content: {
                "application/json" => {
                  schema: {
                    type: "object",
                    properties: {
                      tasks: {
                        type: "array",
                        items: { '$ref': "#/components/schemas/Task" }
                      },
                      meta: { '$ref': "#/components/schemas/PaginationMeta" }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/notifications" => {
        get: {
          tags: [ "Notifications" ],
          summary: "List notifications",
          parameters: [
            {
              name: "unread_only",
              in: "query",
              schema: { type: "boolean", default: false }
            },
            {
              name: "type",
              in: "query",
              schema: { type: "string" }
            }
          ],
          responses: {
            "200" => {
              description: "List of notifications",
              content: {
                "application/json" => {
                  schema: {
                    type: "object",
                    properties: {
                      notifications: {
                        type: "array",
                        items: { '$ref': "#/components/schemas/Notification" }
                      },
                      meta: { '$ref': "#/components/schemas/PaginationMeta" }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  end
end
