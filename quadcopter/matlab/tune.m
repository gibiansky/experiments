% Compute an optimal set of PID parameters
% by initializing the parameters randomly,
% minimizing a cost function using a numerical gradient
% estimate, repeating this several times, and 
% choosing the best result.
function theta = tune();
    % How many times should we repeat to try to get better results?
    attempts = 10;

    % Keep track of minimum cost so far, and best parameter set.
    min_cost = 1e10;
    best_theta = -1;

    for i = 1:attempts
        % Compute next set of parameters and their costs.
        [theta, costs] = minimize;

        % If this is the best we've seen so far, store it.
        if costs(end) < min_cost
            min_cost = costs(end);
            best_theta = theta;
        end
    end

    % Return best parameters.
    theta = best_theta;
end

% Minimize a cost function by estimating the gradient
% numerically and using modified gradient descent to
% choose the best set of parameters.
function [theta, costs] = minimize()
    % Initialize weights randomly.
    theta = 1 * rand(1, 3);

    % Use a small step size $\alpha$.
    alpha = 0.03;

    % Maximum number of iterations to use.
    % In general, we should not reach this,
    % as we should get to a steady-state earlier.
    max_iterations = 500;

    % Each time we compute cost and gradient, we are actually
    % computing them using different disturbances. In order to make our
    % control parameters general, we take the average of several costs and gradients
    % in order to obtain our estimates for a given parameter set. This variable
    % indicates how many different measurements we average. As we iterate longer,
    % we may want to increase this in order to make our gradients more precise.
    average_length = 3;

    for iteration = 1:max_iterations
        disp(sprintf('Iteration %d...', iteration));

        % Compute costs (with averaging) for the current parameters.
        costs(iteration) = mean_value(@cost, theta, average_length);

        % Check if we can stop. We stop if we have reached a steady-state.
        % In order to decide whether a steady-state has been reached, we
        % look at the previous fifty costs. We fit a line to the graph of
        % costs vs iterations, and if the slope of that line is statisticially
        % insignificant (the 99% confidence interval includes zero), we 
        % say that we have reached a steady state, and stop iterating.
        num_costs = 50;
        if iteration > num_costs + 5
            % Previous fifty costs.
            recent_costs = costs(end - num_costs + 1:end);

            % Compute linear regression, with a bias term b(1) and a slope b(2).
            % Also, compute 99% confidence intervals for the bias and slope.
            [b, int] = regress(recent_costs', [ones(num_costs, 1) (1:num_costs)'], 0.99);
            
            % Find the boundaries of the slope confidence interval.
            % If zero is in-between them, our slope is negligible, and
            % further training is unnecessary. Stop iterating.
            larger = max(int(2, :));
            smaller = min(int(2, :));
            if 0 < larger && 0 > smaller
                break;
            end
        end

        % Change step size and averaging to adjust for training duration.
        % After longer training times, we may want to decrease step size and
        % increase the number of averaged samples, so that our algorithm may
        % be more sensitive to small changes and avoid overshooting the minimum.
        if iteration > 100
            alpha = 0.001;
            average_length = 8;
        elseif iteration > 200
            average_length = 15;
            alpha = 0.0005;
        end

        % Compute gradient for our parameters (with averaging).
        grad = mean_value(@gradient, theta, average_length);

        % Adjust parameters using step size and gradient.
        theta = theta - alpha * grad;
    end
end

% Given a function that has some random component and
% may return different values for the same input, as well
% as an input for that function, compute N values for
% that function and return their average.
function value = mean_value(func, input, n)
    % Compute first one out of loop, to determine size(value).
    value = func(input);

    for i = 2:n
        value = value + func(input);
    end
    value = value / n;
end

% Numerically estimate the gradient of the cost function
% at a particular point in PID parameter space.
function grad = gradient(theta)
    % Use a very small displacement to estimate the limit.
    delta = 0.001;

    % Store random seed, so that all simulations are using the same disturbance.
    % Although different gradients may use different disturbances, we want the different
    % components of the gradient to be computed using the same simulation.
    s = rng;

    for i = 1:length(theta)
        var = zeros(size(theta));
        var(i) = 1;

        % Restore the random seed for each cost computation.
        % This way, the simulation that's done is the same every time.
        rng(s); left_cost = cost(theta + delta * var);
        rng(s); right_cost = cost(theta - delta * var);

        % Compute gradient with respect to ith parameter.
        grad(i) = (left_cost - right_cost) / (2 * delta);
    end
end

% Compute the cost function for a given parameter set.
% The cost function is defined as:
%   $J(\theta) = \frac{1}{t_f - t_0} \int_{t_0}^{t_f} e(t, \theta)^2 dt$
% where $e(t, \theta)$ is the error at time $t$.
function J = cost(theta)
    % Create a controller using the given gains.
    control = controller('pid', theta(1), theta(2), theta(3));

    % Perform a simulation. Only simulate the first second, and
    % use a relatively large time-step. We do many simulations for
    % each iteration of the tuning, so we need each simulation to be quite fast.
    data = simulate(control, 0, 1, 0.05);

    % Compute the integral, $\frac{1}{t_f - t_0} \int_{t_0}^{t_f} e(t)^2 dt$
    errors = sqrt(sum(data.theta .^ 2));
    J = sum(errors .^ 2) * data.dt;
end
